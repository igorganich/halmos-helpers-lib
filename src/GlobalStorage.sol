// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "./Cheats.sol";

/*
** The point of this auxiliary contract is to conveniently store the data 
** needed for efficient symbolic execution.
*/
contract GlobalStorage is FoundryCheats, HalmosCheats {
    address public constant configurer = address(uint160(uint256(keccak256("halmos-helpers-lib configurer address"))));
    address public constant callbacker = address(uint160(uint256(keccak256("halmos-helpers-lib callbacker address"))));

    bool public verbose_mode;

    function setVerboseMode(bool _debug_mode) external {
        _vm.assume(msg.sender == configurer);
        debug_mode = _debug_mode;
    }
    /*
    ** fallback and receive counter functionality. This controls the number of automatic receive() and fallback() handles.
    ** This number is common to all SymbolicActor instances
    */
    uint8 public max_symbolic_fallback;
    uint8 public max_symbolic_receive;

    uint8 public symbolic_fallback_counter = 0;
    uint8 public symbolic_receive_counter = 0;

    function setSymbolicCallbacksDepth(uint8 _max_symbolic_fallback,
                                                uint8 _max_symbolic_receive)
                                                external {
        _vm.assume(msg.sender == configurer);
        max_symbolic_fallback = _max_symbolic_fallback;
        max_symbolic_receive = _max_symbolic_receive;
    }

    function incrementFallbackCount() external {
        _vm.assume(msg.sender == callbacker);
        symbolic_fallback_counter++;
        _vm.assume(symbolic_fallback_counter <= max_symbolic_fallback);
    }

    function incrementReceiveCount() external {
        _vm.assume(msg.sender == callbacker);
        symbolic_receive_counter++;
        _vm.assume(symbolic_receive_counter <= max_symbolic_receive);
    }

    function decrementFallbackCount() external {
        _vm.assume(msg.sender == callbacker);
        symbolic_fallback_counter--;
    }

    function decrementReceiveCount() external {
        _vm.assume(msg.sender == callbacker);
        symbolic_receive_counter--;
    }

    /* 
    ** Set or unset no-duplicate-calls mode
    */
    bool private no_duplicate_calls = false;

    function setNoDuplicateCalls(bool _no_duplicate_calls) external {
        _vm.assume(msg.sender == configurer);
        no_duplicate_calls = _no_duplicate_calls;
    }

    bool private only_allowed_selectors = false;

    function setOnlyAllowedSelectors(bool _only_allowed_selectors) external {
        _vm.assume(msg.sender == configurer);
        only_allowed_selectors = _only_allowed_selectors;
    }

    /*
    ** Known SymbolicActors contract
    */

    mapping (address => bool) registered_actors;

    function registerSymbolicActor(address actor) external {
        _vm.assume(msg.sender == configurer);
        registered_actors[actor] = true;
        console.log("-------------------------------------------");
        console.log("[halmos-helpers] Registered SymbolicActor contract: ", actor);
    }

    function assumeNotDelegateCall(address actor) external view {
        _vm.assume(registered_actors[actor] == true);
    }

    /*
    ** Known target contracts
    */
    mapping (uint256 => address) target_contracts;
    mapping (address => string) public names_by_addr;
    uint256 target_contracts_list_size = 0;

    function addAddrNamePair(address addr, string memory name) external {
        _vm.assume(msg.sender == configurer);
        target_contracts[target_contracts_list_size] = addr;
        target_contracts_list_size++;
        names_by_addr[addr] = name;
        console.log("-------------------------------------------");
        console.log("[halmos-helpers] Registered target contract: ", addr);
        console.log("[halmos-helpers] name: ", name);
    }

    /* 
    ** Selectors that are banned to consider during symbolic execution. 
    */ 
    mapping (bytes4 => bool) banned_selectors;

    function addBannedFunctionSelector(bytes4 selector) external {
        _vm.assume(msg.sender == configurer);
        banned_selectors[selector] = true;
        delete allowed_selectors[selector];
    }

    /*
    ** Selectors that are allowed to consider during symbolic execution. 
    */
    mapping (bytes4 => bool) allowed_selectors;

    function addAllowedFunctionSelector(bytes4 selector) external {
        _vm.assume(msg.sender == configurer);
        allowed_selectors[selector] = true;
        delete banned_selectors[selector];
    }

    /*
    ** Selectors that have already been used in symbolic execution.
    ** Only applicable in no_duplicate_calls mode.
    */ 
    mapping (bytes4 => bool) used_selectors;

    /*
    ** if addr is a concrete value, this returns (addr, symbolic calldata for addr)
    ** if addr is symbolic, execution will split for each feasible case and it will return
    **      (addr0, symbolic calldata for addr0), (addr1, symbolic calldata for addr1),
            ..., and so on (one pair per path)
    ** if addr is symbolic but has only 1 feasible value (e.g. with vm.assume(addr == ...)),
            then it should behave like the concrete case
    ** if "no_duplicate_calls" traversal is used - already used selectors will not be taken into account
    */
    /// @custom:halmos --loop 256
    function getConcreteAddrAndData(address /*symbolic*/ addr) external
                                        returns (address ret, bytes memory data) 
    {
        bytes4 selector = _svm.createBytes4("GlobalStorage_selector");
        for (uint256 i = 0; i < target_contracts_list_size; i++) {
            if (target_contracts[i] == addr) {
                string memory name = names_by_addr[target_contracts[i]];
                ret = target_contracts[i];
                data = _svm.createCalldata(name);
                _vm.assume(selector == bytes4(data));
                _vm.assume(banned_selectors[selector] != true);
                if (no_duplicate_calls) {
                    _vm.assume(used_selectors[selector] != true);
                    used_selectors[selector] = true;
                }
                if (only_allowed_selectors) {
                    _vm.assume(allowed_selectors[selector] == true);
                }
                return (ret, data);
            }
        }
        _vm.assume(false); // Ignore cases when addr is not some concrete known address
    }
}
