// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "./GlobalStorage.sol";
import "halmos-cheatcodes/SymTest.sol";
import "./SymbolicHandler.sol";

contract SymbolicHandlerUtils is Test, SymTest {
    function execute_actor_handler_pair(address[] memory actors, SymbolicHandler[] memory handlers, bytes calldata action) 
                                        external returns (bool success, bytes memory ret) {
        if (actors.length != handlers.length) {
            console.log("[SymbolicHandlerUtils] Actors and Handlers arrays size don't match");
            vm.assume(false);
        }
        
        address actor = svm.createAddress("execute_actor_handler_pair");
        for (uint8 i = 0; i < actors.length; i++) {
            if (actor == actors[i]) {
                vm.startPrank(actors[i]);
                if (handlers[i].owner() != actors[i]) {
                    console.log("[SymbolicHandlerUtils] Handler's owner doesn't match with actor");
                    vm.assume(false);
                }
                (success, ret) = address(handlers[i]).call(action);
                vm.stopPrank();
                return (success, ret);
            }
        }
        vm.assume(false); // Ignore cases where actor-handler pair was not found
        return (false, ""); // This line is expected to never be hit
    }
}