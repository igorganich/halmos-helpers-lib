// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "./Cheats.sol";

/*
** The point of this auxiliary contract is to conveniently store the data 
** needed for efficient symbolic execution.
*/
contract GlobalStorage is FoundryCheats, HalmosCheats {
    address immutable configurer;

    constructor(address _configurer) {
        configurer = _configurer;
    }

    /* 
    ** Known target contracts
    */
    mapping (uint256 => address) target_contracts;
    mapping (address => string) names_by_addr;
    uint256 target_contracts_list_size = 0;

    function add_addr_name_pair(address addr, string memory name) external {
        _vm.assume(msg.sender == configurer);
        target_contracts[target_contracts_list_size] = addr;
        target_contracts_list_size++;
        names_by_addr[addr] = name;
    }

    /* 
    ** Selectors that are banned to consider during symbolic execution. 
    */ 
    mapping (uint256 => bytes4) banned_selectors;
    uint256 banned_selectors_size = 0;

    function add_banned_function_selector(bytes4 selector) external {
        _vm.assume(msg.sender == configurer);
        banned_selectors[banned_selectors_size] = selector;
        banned_selectors_size++;
    }

    /*
    ** Selectors that have already been used in symbolic execution.
    ** Only applicable in optimistic mode.
    */ 
    mapping (uint256 => bytes4) used_selectors;
    uint256 used_selectors_size = 0;

    /*
    ** if addr is a concrete value, this returns (addr, symbolic calldata for addr)
    ** if addr is symbolic, execution will split for each feasible case and it will return
    **      (addr0, symbolic calldata for addr0), (addr1, symbolic calldata for addr1),
            ..., and so on (one pair per path)
    ** if addr is symbolic but has only 1 feasible value (e.g. with vm.assume(addr == ...)),
            then it should behave like the concrete case
    ** if "optimistic" traversal is used - already used selectors will not be taken into account
    */
    /// @custom:halmos --loop 256
    function get_concrete_addr_and_data(address /*symbolic*/ addr, bool is_optimistic) external
                                        returns (address ret, bytes memory data) 
    {
        bytes4 selector = _svm.createBytes4("GlobalStorage_selector");

        for (uint256 s = 0; s < banned_selectors_size; s++) {
            _vm.assume(selector != banned_selectors[s]);
        }

        if (is_optimistic) {
            for (uint256 s = 0; s < used_selectors_size; s++) {
                _vm.assume(selector != used_selectors[s]);
            }
            used_selectors[used_selectors_size++] = selector;
        }

        for (uint256 i = 0; i < target_contracts_list_size; i++) {
            if (target_contracts[i] == addr) {
                string memory name = names_by_addr[target_contracts[i]];
                ret = target_contracts[i];
                data = _svm.createCalldata(name);
                _vm.assume(selector == bytes4(data));
                return (ret, data);
            }
        }
        _vm.assume(false); // Ignore cases when addr is not some concrete known address
    }
}
