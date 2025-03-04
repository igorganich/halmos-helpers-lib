// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "./GlobalStorage.sol";
import "halmos-cheatcodes/SymTest.sol";

contract SymbolicHandler is Test, SymTest {
    GlobalStorage immutable glob;
    address immutable configurer;
    address immutable public owner;
    bool private is_optimistic = false;
    uint8 private symbolic_txs_number = 1;
    uint8 private symbolic_fallback_txs_number = 1;
    uint8 private symbolic_receive_txs_number = 1;

    constructor (address _owner, GlobalStorage _glob, address _configurer) {
        owner = _owner;
        glob = _glob;
        configurer = _configurer;
    }

    function set_is_optimistic(bool _is_optimistic) external {
        vm.assume(msg.sender == configurer);
        is_optimistic = _is_optimistic;
    }

    function set_symbolic_txs_number(uint8 number) external {
        vm.assume(msg.sender == configurer);
        symbolic_txs_number = number;
    }
    function set_symbolic_fallback_txs_number(uint8 number) external {
        vm.assume(msg.sender == configurer);
        symbolic_fallback_txs_number = number;
    }
    function set_symbolic_receive_txs_number(uint8 number) external {
        vm.assume(msg.sender == configurer);
        symbolic_receive_txs_number = number;
    }
   
    bool fallback_reent_blocker = false;
    bool receive_reent_blocker = false;
    bool execute_symbolically_reent_blocker = false;

    function sym_tx_to_any(string memory target_name) private {
        address target = svm.createAddress(target_name);
        uint256 ETH_val = svm.createUint256("ETH_val");
        bytes memory data;
        //Get some concrete target-name pair
        (target, data) = glob.get_concrete_addr_and_data(target, is_optimistic);
        uint snap0 = vm.snapshotState();
        target.call{value: ETH_val}(data);
        uint snap1 = vm.snapshotState();
        vm.assume(snap0 != snap1);
    }

    function sym_tx_to_target(address target) private {
        uint256 ETH_val = svm.createUint256("ETH_val");
        bytes memory data;
        (target, data) = glob.get_concrete_addr_and_data(target, is_optimistic);
        uint snap0 = vm.snapshotState();
        target.call{value: ETH_val}(data);
        uint snap1 = vm.snapshotState();
        vm.assume(snap0 != snap1);
    }

    /// @custom:halmos --loop 256
    fallback() external payable {
        vm.assume(false == fallback_reent_blocker); // Don't fall into recursion here
        fallback_reent_blocker = true;
        // Function selector this fallback was called from
        bytes4 selector = svm.createBytes4("fallback_selector"); 
        vm.assume(selector == bytes4(msg.data));

        // fallback may execute some set of transactions or revert
        bool is_revert = svm.createBool("fallback_is_revert");
        if (false == is_revert) {
            for (uint8 i = 0; i < symbolic_fallback_txs_number; i++) {
                sym_tx_to_any("fallback_target");
            }
            fallback_reent_blocker = false;
            bytes memory retdata = svm.createBytes(1000, "fallback_retdata");// something should be returned
            assembly {
                return(add(retdata, 0x20), mload(retdata))
            }
        } else {
            revert();
        }
    }

    /// @custom:halmos --loop 256
    receive() external payable {
        vm.assume(false == receive_reent_blocker); // Don't fall into recursion here
        receive_reent_blocker = true;

        // receive may execute some set of transactions or revert
        bool is_revert = svm.createBool("receive_is_revert");
        if (false == is_revert) {
            for (uint8 i = 0; i < symbolic_receive_txs_number; i++) {
                sym_tx_to_any("receive_target");
            }
        } else {
            revert();
        }
        receive_reent_blocker = false;
    }

    /*
    ** Symbolically execute all possible transactions to all known targets
    */
    /// @custom:halmos --loop 256
    function execute_symbolically_all() external {
        vm.assume(msg.sender == owner);
        vm.assume(false == execute_symbolically_reent_blocker);
        execute_symbolically_reent_blocker = true;
        for (uint8 i = 0; i < symbolic_txs_number; i++) {
            sym_tx_to_any("execute_symbolically_all_target");
        }
        execute_symbolically_reent_blocker = false;
    }

    /*
    ** Symbolically execute all possible transactions to some concrete target
    ** The target parameter is expected to be NON-SYMBOLIC, 
    ** otherwise this function will behave like execute_symbolically_all()!
    */
    /// @custom:halmos --loop 256
    function execute_symbolically_target(address /* non-symbolic */ target) external {
        vm.assume(msg.sender == owner);
        vm.assume(false == execute_symbolically_reent_blocker);
        execute_symbolically_reent_blocker = true;
        for (uint8 i = 0; i < symbolic_txs_number; i++) {
            sym_tx_to_target(target);
        }
        execute_symbolically_reent_blocker = false;
    }

    /* 
    ** Just execute some call on behave of SymbolicHandler
    */
    function execute_symbolically_target_data(address /* non-symbolic */ target, bytes memory data) external {
        vm.assume(msg.sender == owner);
        vm.assume(false == execute_symbolically_reent_blocker);
        execute_symbolically_reent_blocker = true;
        target.call(data);
        execute_symbolically_reent_blocker = false;
    }
}