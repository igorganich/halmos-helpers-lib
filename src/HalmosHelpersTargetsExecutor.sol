// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "./GlobalStorage.sol";

abstract contract HalmosHelpersTargetsExecutor is FoundryCheats, HalmosCheats {

    /*
    ** return GlobalStorage instance dynamically to avoid taking up a slot in the storage
    */
    function get_GlobalStorage() internal pure returns (GlobalStorage)  {
        return GlobalStorage(address(uint160(uint256(keccak256("halmos-helpers-lib GlobalStorage address")))));
    }

    /*
    ** return address of callbacker pseudo-actor to increment and decrement callbacks count
    */
    function get_callbacker() private view returns (address) {
        return get_GlobalStorage().callbacker();
    }

    function assumeNotDelegateCall() internal view {
        get_GlobalStorage().assumeNotDelegateCall(address(this));
    }

    /*
    ** increment and decrement number of callbacks in the current path
    */
    function incrementFallbackCount() internal {
        _vm.startPrank(get_callbacker());
        get_GlobalStorage().incrementFallbackCount();
        _vm.stopPrank();
    }

    function decrementFallbackCount() internal {
        _vm.startPrank(get_callbacker());
        get_GlobalStorage().decrementFallbackCount();
        _vm.stopPrank();
    }

    function incrementReceiveCount() internal {
        _vm.startPrank(get_callbacker());
        get_GlobalStorage().incrementReceiveCount();
        _vm.stopPrank();
    }

    function decrementReceiveCount() internal {
        _vm.startPrank(get_callbacker());
        get_GlobalStorage().decrementReceiveCount();
        _vm.stopPrank();
    }

    /*
    ** This function will symbolically call all functions of all contracts registered in the glob
    */
    function symTxToAny(string memory identificator) private returns (bool, bytes memory) {
        address target = _svm.createAddress(identificator);
        uint256 ETH_val = _svm.createUint256("ETH_val");
        bytes memory data;
        //Get some concrete target-name pair
        (target, data) = get_GlobalStorage().getConcreteAddrAndData(target);
        uint snap0 = _vm.snapshotState();
        if (get_GlobalStorage().verbose_mode()) {
            console.log("-------------------------------------------------------------------------------");
            console.log("[halmos-helpers verbose] executing symTxToAny: ", target);
            console.log("[halmos-helpers verbose] target name: ", get_GlobalStorage().names_by_addr(target));
            console.log("[halmos-helpers verbose] symbolic transaction identificator: ", identificator);
            console.log("[halmos-helpers verbose] msg.sender: ", msg.sender);
            console.logBytes(data);
            console.log("-------------------------------------------------------------------------------");
        }
        (bool success, bytes memory res) = target.call{value: ETH_val}(data);
        uint snap1 = _vm.snapshotState();
        _vm.assume(snap0 != snap1);
        return (success, res);
    }

    /*
    ** This function will symbolically call all functions of some target
    */
    function symTxToTarget(address /* non-symbolic */ target) private returns (bool, bytes memory) {
        uint256 ETH_val = _svm.createUint256("ETH_val");
        bytes memory data;
        (target, data) = get_GlobalStorage().getConcreteAddrAndData(target);
        uint snap0 = _vm.snapshotState();
        if (get_GlobalStorage().verbose_mode()) {
            console.log("-------------------------------------------------------------------------------");
            console.log("[halmos-helpers verbose] executing symTxToTarget: ", target);
            console.log("[halmos-helpers verbose] target name: ", get_GlobalStorage().names_by_addr(target));
            console.log("[halmos-helpers verbose] msg.sender: ", msg.sender);
            console.logBytes(data);
            console.log("-------------------------------------------------------------------------------");
        }
        (bool success, bytes memory res) = target.call{value: ETH_val}(data);
        uint snap1 = _vm.snapshotState();
        _vm.assume(snap0 != snap1);
        return (success, res);
    }

    /*
    ** Symbolically execute all possible transactions to all known targets
    */
    /// @custom:halmos --loop 256
    function executeSymbolicallyAllTargets(string memory identificator) internal returns (bool, bytes memory) {
        return symTxToAny(identificator);
    }

    function executeSymbolicallyTarget(address target) internal returns (bool, bytes memory) {
        return symTxToTarget(target);
    }
}