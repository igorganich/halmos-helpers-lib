// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "./HalmosHelpersTargetsExecutor.sol";

contract SymbolicActor is HalmosHelpersTargetsExecutor {
    address immutable configurer;
    uint8 private symbolic_fallback_txs_number;
    uint8 private symbolic_receive_txs_number;

    constructor (address _configurer) {
        configurer = _configurer;
        symbolic_fallback_txs_number = 1;
        symbolic_receive_txs_number = 1;
    }

    /*
    ** Setters to configure behavior of symbolic actors
    ** We need a special configurer address because there is a possibility that some contract will symbolically 
    ** call SymbolicActor's config function and we would not want the configuration to get messed up because of this
    */
    function setSymbolicFallbackTxsNumber(uint8 number) external {
        _vm.assume(msg.sender == configurer);
        symbolic_fallback_txs_number = number;
    }
    function setSymbolicReceiveTxsNumber(uint8 number) external {
        _vm.assume(msg.sender == configurer);
        symbolic_receive_txs_number = number;
    }

    /*
    ** This function allows us to automatically handle any call made to a SymbolicActor.
    ** Its most likely use is as a various callbacks like IERC3156FlashBorrower.onFlashLoan()
    ** Also, if the fallback resulted in a counterexample - the counterexample will show the exact 
    ** name of the function that was called at that address and which triggered the fallback (using fallback_selector)
    */
    /// @custom:halmos --loop 256
    fallback() external payable {
        // Deny use of this function as delegatecallee to avoid recursion
        assumeNotDelegateCall();
        incrementFallbackCount();
        // Function selector this fallback was called from
        bytes4 selector = _svm.createBytes4("fallback_selector"); 
        _vm.assume(selector == bytes4(msg.data));
        bool is_empty = _svm.createBool("fallback_is_empty");
        if (!is_empty) {
            // fallback may execute some set of transactions or revert
            bool is_revert = _svm.createBool("fallback_is_revert");
            if (false == is_revert) {
                for (uint8 i = 0; i < symbolic_fallback_txs_number; i++) {
                    executeSymbolicallyAllTargets("fallback_target");
                }
            } else {
                revert();
            } 
        }
        decrementFallbackCount();
        bytes memory retdata = _svm.createBytes(1000, "fallback_retdata");// something should be returned
        assembly {
            return(add(retdata, 0x20), mload(retdata))
        }
    }

    /*
    ** This function allows us to automatically handle ETH payments to SymbolicActor. 
    ** Just execute some number (symbolic_receive_txs_number) functions to target contracts symbolically
    */
    /// @custom:halmos --loop 256
    receive() external payable {
        // Deny use of this function as delegatecallee to avoid recursion
        assumeNotDelegateCall();
        incrementReceiveCount();
        bool is_empty = _svm.createBool("receive_is_empty");
        if (!is_empty) {
            // receive may execute some set of transactions or revert
            bool is_revert = _svm.createBool("receive_is_revert");
            if (false == is_revert) {
                for (uint8 i = 0; i < symbolic_receive_txs_number; i++) {
                    executeSymbolicallyAllTargets("receive_target");
                }
            } else {
                revert();
            }
        }
        decrementReceiveCount();
    }
}