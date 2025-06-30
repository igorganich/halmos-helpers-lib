// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "./HalmosHelpersTargetsExecutor.sol";
import "./GlobalStorage.sol";
import "./SymbolicActor.sol";

import "forge-std/Test.sol";

abstract contract HalmosHelpers is HalmosHelpersTargetsExecutor {
    function getConfigurer() internal pure returns (address) {
        return address(uint160(uint256(keccak256("halmos-helpers-lib configurer address"))));
    }

    /*
    ** Initialize all necessary instances to use halmos-helpers:
    ** 1) etch GlobalStorage on specific address
    ** 2) ...
    */
    function halmosHelpersInitialize() internal {
        GlobalStorage newglob = new GlobalStorage();
        bytes memory code = address(newglob).code;
        _vm.etch(address(get_GlobalStorage()), code);
        get_GlobalStorage().setSymbolicCallbacksDepth(1, 1);
    }

    /*
    ** This controls the number of automatic receive() and fallback() handles
    */
    function halmosHelpersSetSymbolicCallbacksDepth(uint8 _max_symbolic_fallback,
                                                                uint8 _max_symbolic_receive) internal {
        get_GlobalStorage().setSymbolicCallbacksDepth(_max_symbolic_fallback, _max_symbolic_receive);
    }

    /*
    ** Initialize and return an array of SymbolicActor contracts
    */
    function halmosHelpersGetSymbolicActorArray(uint8 size) internal returns(SymbolicActor[] memory actors) {
        actors = new SymbolicActor[](size);
        for (uint8 i = 0; i < size; i++) {
            actors[i] = new SymbolicActor(getConfigurer());
            get_GlobalStorage().registerSymbolicActor(address(actors[i]));
        }
    }

    /*
    ** You can pass some array of SymbolicActors here. This function will start a prank with a symbolic msg.sender, 
    ** taking into account that the pranker can be any SymbolicActor from this array.
    ** The implementation of this function looks very strange, I hope there is a better way to do this without performance sacrificing
    */
    function halmosHelpersSymbolicBatchStartPrank(SymbolicActor[] memory actors) internal {
        if (actors.length > 10) {
            console.log("[halmos-helpers] Maximum expected actors array size is 10");
            revert();
        }
        if (actors.length == 0) {
            console.log("[halmos-helpers] actors array size should be at least of size 1");
            revert();
        }
        address batch_prank_addr = _svm.createAddress("batch_prank_addr");
        if (actors.length == 1) {
            _vm.assume(batch_prank_addr == address(actors[0]));
        }
        else if (actors.length == 2) {
            _vm.assume(batch_prank_addr == address(actors[0]) || batch_prank_addr == address(actors[1]));
        }
        else if (actors.length == 3) {
            _vm.assume(batch_prank_addr == address(actors[0]) || batch_prank_addr == address(actors[1]) || batch_prank_addr == address(actors[2]));
        }
        else if (actors.length == 4) {
            _vm.assume(batch_prank_addr == address(actors[0]) || batch_prank_addr == address(actors[1]) || batch_prank_addr == address(actors[2]) || batch_prank_addr == address(actors[3]));
        }
        else if (actors.length == 5) {
            _vm.assume(batch_prank_addr == address(actors[0]) || batch_prank_addr == address(actors[1]) || batch_prank_addr == address(actors[2]) || batch_prank_addr == address(actors[3]) || batch_prank_addr == address(actors[4]));
        }
        else if (actors.length == 6) {
            _vm.assume(batch_prank_addr == address(actors[0]) || batch_prank_addr == address(actors[1]) || batch_prank_addr == address(actors[2]) || batch_prank_addr == address(actors[3]) || batch_prank_addr == address(actors[4]) || batch_prank_addr == address(actors[5]));
        }
        else if (actors.length == 7) {
            _vm.assume(batch_prank_addr == address(actors[0]) || batch_prank_addr == address(actors[1]) || batch_prank_addr == address(actors[2]) || batch_prank_addr == address(actors[3]) || batch_prank_addr == address(actors[4]) || batch_prank_addr == address(actors[5]) || batch_prank_addr == address(actors[6]));
        }
        else if (actors.length == 8) {
            _vm.assume(batch_prank_addr == address(actors[0]) || batch_prank_addr == address(actors[1]) || batch_prank_addr == address(actors[2]) || batch_prank_addr == address(actors[3]) || batch_prank_addr == address(actors[4]) || batch_prank_addr == address(actors[5]) || batch_prank_addr == address(actors[6]) || batch_prank_addr == address(actors[7]));
        }
        else if (actors.length == 9) {
            _vm.assume(batch_prank_addr == address(actors[0]) || batch_prank_addr == address(actors[1]) || batch_prank_addr == address(actors[2]) || batch_prank_addr == address(actors[3]) || batch_prank_addr == address(actors[4]) || batch_prank_addr == address(actors[5]) || batch_prank_addr == address(actors[6]) || batch_prank_addr == address(actors[7]) || batch_prank_addr == address(actors[8]));
        }
        else if (actors.length == 10) {
            _vm.assume(batch_prank_addr == address(actors[0]) || batch_prank_addr == address(actors[1]) || batch_prank_addr == address(actors[2]) || batch_prank_addr == address(actors[3]) || batch_prank_addr == address(actors[4]) || batch_prank_addr == address(actors[5]) || batch_prank_addr == address(actors[6]) || batch_prank_addr == address(actors[7]) || batch_prank_addr == address(actors[8]) || batch_prank_addr == address(actors[9]));
        }
        _vm.startPrank(batch_prank_addr);
    }

    /*
    ** Specify the address and name of the contract that will be considered as a target during the symbolic test
    */
    function halmosHelpersRegisterTargetAddress(address target, string memory name) internal {
        get_GlobalStorage().addAddrNamePair(target, name);    
    }

    /*
    ** Allow the function from symbolic test by its selector
    ** Executing this function removes the selector from the "banned" list
    */
    function halmosHelpersAllowFunctionSelector(bytes4 selector) internal {
        get_GlobalStorage().addAllowedFunctionSelector(selector);
    }

    /*
    ** Exclude the function from symbolic test by its selector
    ** Executing this function removes the selector from the "allowed" list
    */
    function halmosHelpersBanFunctionSelector(bytes4 selector) internal {
        get_GlobalStorage().addBannedFunctionSelector(selector);
    }

    /*
    ** Disable or enable only-allowed-selectors mode (default is disabled)
    */
    function halmosHelpersSetOnlyAllowedSelectors(bool _only_allowed_selectors) internal {
        get_GlobalStorage().setOnlyAllowedSelectors(_only_allowed_selectors);
    }

    /*
    ** Disable or enable no-duplicate-calls mode (default is disabled)
    */
    function halmosHelpersSetNoDuplicateCalls(bool _no_duplicate_calls) internal {
        get_GlobalStorage().setNoDuplicateCalls(_no_duplicate_calls);
    }
}