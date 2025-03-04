// SPDX-License-Identifier: GPL-3.0

/* 
** Helper for easy use of Foundry cheats inside of target contracts
*/

pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Test.sol";
import "halmos-cheatcodes/SymTest.sol";

abstract contract FoundryCheats {
    Vm internal constant _vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
}

abstract contract HalmosCheats {
    SVM internal constant _svm = SVM(address(uint160(uint256(keccak256("svm cheat code")))));
}
