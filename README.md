# halmos-helpers-lib
**halmos-helpers-lib** is a solidity library for quick and convenient preparation of solidity project for symbolic execution stateful checks under the [halmos](https://github.com/a16z/halmos) engine. The main idea of this library is to allow the test developer to create powerful symbolic tests, covering as much work as possible automatically (for example, now you don't need to implement monstrous **handlers** with custom **callback** implementations - this is processed automatically). It contains functionality for automatic processing of **reentrancy**, malicious and fully mocked external contracts, **DoS** scenarios, provides a framework for flexible stateful invariant testing, using many optimizations and much more!

Essentially, it is a collection of contracts that, through some abstractions that symbolic execution allows, provide the ability to describe the check **setup**, **scenarios**, and **invariants** in a fairly abstract way.

Important thing: despite the fact that there is already some powerful functionality, in the real world you can encounter some usage limitations. Therefore, I would like even **RECOMMEND** adapting and patching the code of this library for your specific cases, using the existing functionality as a basis.
## Target halmos version
This library is currently compatible with `halmos 0.3.0`. Many features are not compatible with older halmos versions. I also cannot guarantee that it will work on newer versions of halmos. I will try to keep it compatible with the latest version of halmos. Feel free to make pull requests to both help me keep it fresh and to suggest any changes to the functionality.
## How to connect this library to your test suite?
1. Clone this repository (or add it as a submodule to your repository)
2. Add **halmos-helpers-lib** to your `remappings.txt`:
```txt
...
halmos-helpers-lib/=/path/to/halmos-helpers-lib/src/
...
```
3. Import the `HalmosHelpers.sol` file:
```solidity
import "halmos-helpers-lib/HalmosHelpers.sol";
```
4. Make your **halmos** test contract inherited from `HalmosHelpers`:
```solidity
contract MyHalmosTestContract is Test, HalmosHelpers {
    ...
}
```
### soldeer
This library is also available on [soldeer](https://soldeer.xyz/project/halmos-helpers-lib)
## Examples
There is a [repository](https://github.com/igorganich/halmos-helpers-examples) that contains examples of using this library in practice.
## Basic idea
To successfully prepare a smart contracts set for stateful symbolic testing, we need to describe a few things:
1. Setup
2. Actors
3. Which contracts and functions will be covered
4. Scenarios that will be tested
5. Invariants to check

After this preparation, we run a stateful symbolic test. 

For instance, a textbook stateful symbolic test scenario: we run all possible calls that this set of actors can execute, limited by the set of contracts and functions from the setup, for some limited sequence of transactions.

In the context of **halmos-helpers-lib**, here are the typical steps for preparing a stateful symbolic test:
1. In `SetUp()` we deploy the entire system of contracts that we will test.
2. Still in `SetUp()`, we initialize some number of special **actors**. They play the role of system participants.
3. Next, still in `SetUp()`, we register target contracts. Essentially, we specify that **actors** will call functions from these contracts during a stateful symbolic test.
4. The last stage in `SetUp()` is to make some configurations to the behavior of the actors and the overall traversal of the symbolic test.
5. We describe the test scenario in abstract form: we indicate which actors will execute transactions to target contracts, how many such transactions there will be, whether there will be a time interval between transactions, etc.
6. We describe an invariant - a condition that must be fulfilled after the symbolic scenario is executed.

To achieve this goal and facilitate these actions, this library operates with the next major entities:
1. `configurer` pseudo-actor
2. Target contracts
3. `SymbolicActor` contracts

Each of these entities will be described a little later.

## Typical usage example
Without going into detail, here is what a typical implementation of a stateful symbolic test using this library looks like:
```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

// Import necessary contracts
import "halmos-helpers-lib/HalmosHelpers.sol";
import "/path/to/Target1.sol";
import "/path/to/Target2.sol";

contract MultipleActorsAndContracts is Test, HalmosHelpers {
    address deployer = address(0xcafe0000);
    SymbolicActor[] actors; // actors, system participants
    // Target contracts
    Target1 target1;
    Target2 target2;

    function setUp() public {
        vm.startPrank(getConfigurer());
        halmosHelpersInitialize(); // Initialize HalmosHelpers stuff
        actors = halmosHelpersGetSymbolicActorArray(2); // Initialize 2 Actors
        vm.stopPrank();

        // Deploy targets
        vm.startPrank(deployer);
        target1 = new Target1(address(actors[0]));
        target2 = new Target2(target1, address(actors[1]));
        vm.stopPrank();

        vm.startPrank(getConfigurer());
        // Register targets. Their functions will be called by actors during symbolic execution
        halmosHelpersRegisterTargetAddress(address(target1), "Target1");
        halmosHelpersRegisterTargetAddress(address(target2), "Target2");
        
        // Some general configuration of test behavior
        halmosHelpersSetNoDuplicateCalls(true);
        vm.stopPrank();
    }

    // Stateful symbolic test description
    function check_TypicalExample() external {
        halmosHelpersSymbolicBatchStartPrank(actors); // 1st transaction may be executed by any actor
        executeSymbolicallyAllTargets("check_TypicalExample_1"); // Run 1st symbolic transaction. The target may be any address
        vm.stopPrank();

        halmosHelpersSymbolicBatchStartPrank(actors); // 2nd transaction may be executed by any actor
        executeSymbolicallyAllTargets("check_TypicalExample_2"); // Run 2nd symbolic transaction. The target may be any address
        vm.stopPrank();

        assert(target2.goal() != true); // Check whether target2.goal() is always false after any two transactions
    }
}
```
This code is enough to check some invariant after all possible combinations of transactions that can be made by 2 actors regarding these 2 targets. See [this](https://github.com/igorganich/halmos-helpers-examples/tree/main/examples/coverage/07_multiple_actors_and_contracts) example
## configurer overview
`configurer` is a special pseudo-actor that only has the right to change the configuration of `SymbolicActor` contracts and `halmos-helpers` properties. Only this pseudo-actor can regulate which functions and how they will be considered during symbolic execution, how actors will handle callbacks (more on this later), and more. This is done due to the peculiarities of symbolic execution under **halmos**. There is a possibility that some target contract will symbolically execute some configuration function of our helper contracts. This way we guarantee that the only way to change the configuration at runtime is to run `prank()` on behalf of `configurer` and call the configure function.

So, how do we configure a symbolic test:
```solidity
vm.startPrank(getConfigurer()); // Start prank on behalf of configurer
<execute some configuration functions here>
vm.stopPrank(); // Stop prank
```
In the start of the test you must initialize **halmos-helpers**:
```solidity
vm.startPrank(getConfigurer());
halmosHelpersInitialize(); // Initialize HalmosHelpers stuff
vm.stopPrank();
```
If the test crashes at the target registration stage, you may have forgotten about initialization.
## Target contracts
Target contracts are contracts whose functions will be called by actors during a stateful symbolic test.
### Deployment
Obviously, they need to be deployed first:
```solidity
vm.startPrank(deployer);
...
target = new TargetName(...);
...
vm.stopPrank();
```
### Registration
Once they are deployed, the configurer must register them for symbolic execution. To register, you need to call the `halmosHelpersRegisterTargetAddress()` function and pass it the **address** and **name** of the contract:
```solidity
vm.startPrank(getConfigurer());
...
halmosHelpersRegisterTargetAddress(address(target), "TargetName");
...
vm.stopPrank();
```
### Exclude function from test
By default, during a symbolic test, actors will be able to call **ALL** `external/public` functions of the target contract. If you want to exclude any of the functions, you can use `halmosHelpersBanFunctionSelector()` function. Just pass the selector of the function that needs to be excluded from the symbolic test:
```solidity
vm.startPrank(getConfigurer());
halmosHelpersBanFunctionSelector(some_target.some_function.selector);
vm.stopPrank();
```
This function excludes the selector from the **allowed selectors** list.

See [this](https://github.com/igorganich/halmos-helpers-examples/tree/main/examples/coverage/09_banned_function) example.
### Use only whitelisted functions
The opposite of the previous option is the option to include only a limited set of selectors in the symbolic test.

First, let's describe the set of allowed selectors:
```solidity
vm.startPrank(getConfigurer());
halmosHelpersAllowFunctionSelector(some_target1.some_function1.selector);
halmosHelpersAllowFunctionSelector(some_target2.some_function2.selector);
...
vm.stopPrank();
```
`halmosHelpersAllowFunctionSelector()` excludes the selector from the **banned selectors** list.

Then we turn on the **onlyAllowedSelectors** mode:
```solidity
vm.startPrank(getConfigurer());
halmosHelpersAllowFunctionSelector(true);
vm.stopPrank();
```
## SymbolicActor overview
`SymbolicActor` is a special contract that acts as a system participant and can send transactions to target contracts. 

Question: Why use the contract instead of just `address`?

Answer: This way we can more flexibly configure the actor's interaction with target contracts and, MOST IMPORTANTLY: we can automatically process `receive()` and other callbacks (such as the common `IERC3156FlashBorrower.onFlashLoan()`) without implementing additional logic. The configuration and automatic processing of callbacks will be described a little later. For convenience, you can imagine that each `SymbolicActor` has its own owner, who manages it as a puppet and launches transactions on its behalf. But since we can simply `prank` on behalf of the contract, there is no need to separately describe the owner addresses.
### Initialization
`halmosHelpersGetSymbolicActorArray()` function initializes some number of `SymbolicActors`, registers them for internal use, and returns an array of `SymbolicActors`. This function requires 1 parameter to be passed - the number of SymbolicActors that will be returned:
```solidity
contract SomeContract is Test, HalmosHelpers {
...
SymbolicActor[] actors;
...
    function setUp() public {
    ...
    vm.startPrank(getConfigurer());
    actors = halmosHelpersGetSymbolicActorArray(2); // Initialize 2 SymbolicActors
    vm.stopPrank();
...
```
### Running a symbolic transaction.
When describing a symbolic test scenario, we can specify that the following transaction will be performed by a concrete actor:
```solidity
function check_SomeHalmosTest() external {
    vm.startPrank(actors[0]); // Perform next transaction by a specific actor
    ...
```
Or consider all scenarios where the next transaction can be executed by anyone from some array of actors (`prank` from symbolic actor):
```solidity
function check_SomeHalmosTest() external {
    halmosHelpersSymbolicBatchStartPrank(actors); // Perform next transaction by a symbolic actor from actors array
    ...
```
After that, you can:
1. Run a specific transaction:
    ```solidity
    function check_SomeHalmosTest() external {
        ...
        target.some_function(<parameters>);
        ...
    ```
2. Alternatively, you can use `executeSymbolicallyTarget()`:
    ```solidity
    function check_SomeHalmosTest() external {
        ...
        executeSymbolicallyTarget(address(target));
        ...
    ```
    This call will "split" execution into several separate paths, which will separately consider all possible symbolic calls to all `public/external` functions of the `target` contract. It is important that the target should be "registered".

3. And the last option is to use the `executeSymbolicallyAllTargets()` call:
    ```solidity
    function check_SomeHalmosTest() external {
        ...
        executeSymbolicallyAllTargets("Identifier");
        ...
    ```
With this call, we will also split the execution, but this time we do not take into account any specific target, but all registered targets in general. 
The parameter of this function is an **identifier** `string`. We need this so that the counterexample can more clearly show which call to which target leads to a violation of the invariant.

It's worth noting that functions `executeSymbolicallyTarget()` and `executeSymbolicallyAllTargets()` use some tricky optimization internally. Before symbolic execution of some transaction (and subtransaction) using these functions we make a snapshot dump of the entire state. After the call - we make a snapshot of the entire state again. If the state has not changed - it means that this transaction has guaranteed not led to any changes, so there is no point in continuing the current path. This allows us to save a lot of resources:
```solidity
uint snap0 = _vm.snapshotState();
(bool success, bytes memory res) = target.call{value: ETH_val}(data); // Make a symbolic call to target
uint snap1 = _vm.snapshotState();
_vm.assume(snap0 != snap1); // If snap0 == snap1 -> drop current path
```
### Symbolic receive()
During the symbolic transaction, we may encounter a scenario where someone sends some amount of **ETH** to a certain `SymbolicActor()`. For such cases, the `SymbolicActor` implements a `receive()` callback:
```solidity
contract SymbolicActor is HalmosHelpersTargetsExecutor {
    ...
    receive() external payable {
        ...
        bool is_empty = _svm.createBool("receive_is_empty");
        if (!is_empty) {
            // receive may execute some set of transactions or revert
            bool is_revert = _svm.createBool("receive_is_revert");
            if (false == is_revert) {
                incrementReceiveCount();
                for (uint8 i = 0; i < symbolic_receive_txs_number; i++) {
                    executeSymbolicallyAllTargets("receive_target");
                }
                decrementReceiveCount();
            } else {
                revert();
            }
        }
    ...
}
```
If some path enters this location, the execution will be splitted into 3 cases:
1. Do nothing. Just receive the value.
2. Consider the case where `receive()` does `revert()` (see example about vulnerable [NFT Auction](https://github.com/igorganich/halmos-helpers-examples/tree/main/examples/realworld/DoS_auction)).
3. `receive()` can call some functions internally. Here we simply do the already familiar `executeSymbolicallyAllTargets()` and consider all possible calls to target contracts.

Question: exactly how many such symbolic functions will be called inside `receive()`?

Answer: This is regulated by the configuration function `SymbolicActor::setSymbolicReceiveTxsNumber()`. During configuration, you can specify the number of calls that will be made inside receive() by a specific actor:
```solidity
contract SequenceOf2Receive is Test, HalmosHelpers {
...
    function setUp() public {
        ...
        vm.startPrank(getConfigurer());
        actors = halmosHelpersGetSymbolicActorArray(1);
        actors[0].setSymbolicReceiveTxsNumber(2);
        vm.stopPrank();
        ...
    }
...
}
```
By default, this number is 1.

See [this](https://github.com/igorganich/halmos-helpers-examples/tree/main/examples/coverage/04_sequence_of_2_receive) example.

### Symbolic fallback()
Symbolic `fallback()` is similar to symbolic `receive()`, but there are some important differences. 

First, it is capable of handling any callback without the need to separately implement this function. If in some path some target calls any function of `SymbolicActor`, execution will hit `SymbolicActor::fallback()`. At this point, execution will split into 3 cases we are already familiar with: do nothing, `revert()` or perform some number of symbolic calls to all target contracts. This number is regulated by the configuration function `SymbolicActor::setSymbolicFallbackTxsNumber()`:
```solidity
contract SomeContract is Test, HalmosHelpers {
...
    function setUp() public {
        ...
        vm.startPrank(getConfigurer());
        actors = halmosHelpersGetSymbolicActorArray(1);
        actors[0].setSymbolicFallbackTxsNumber(2);
        vm.stopPrank();
        ...
    }
...
}
```

By default, this number is 1.

See [this](https://github.com/igorganich/halmos-helpers-examples/tree/main/examples/coverage/03_callback) and [this](https://github.com/igorganich/halmos-helpers-examples/tree/main/examples/ctf/side-entrance) examples.

And the second difference is that symbolic `fallback()` will return symbolic bytes array as response:
```solidity
fallback() external payable {
    ...
    bytes memory retdata = _svm.createBytes(1000, "fallback_retdata");// something should be returned
    assembly {
        return(add(retdata, 0x20), mload(retdata))
    }
    ...
}
```
It's worth noting that any `view` function called to a **SymbolicActor** will simply return a symbolic array of bytes anyway.
### Recursive callback handling
During symbolic execution, there may be paths in which `receive()` and `fallback()` callbacks are called multiple times recursively for the same or multiple different actors. The depth of such calls is regulated by a configuration function `halmosHelpersSetSymbolicCallbacksDepth()`:
```solidity
contract SomeContract is Test, HalmosHelpers {
...
    function setUp() public {
        ...
        vm.startPrank(getConfigurer());
        halmosHelpersSetSymbolicCallbacksDepth(2, 3);
        vm.stopPrank();
        ...
    }
...
}
```
The first parameter is the maximum `fallback()` depth, the second parameter is maximum `receive()` depth. Default values are `1` and `1`.
### SymbolicActor as a mock external contract
One of the unusual uses of **SymbolicActor** is to use it as some kind of external contract with an unknown implementation in advance. Imagine that you need to use some universal **mock** that could authomatically return any value from any `view` function, make some set of calls inside of `non-view` functions and process `receive()`. To do this, it is enough to deploy a separate **SymbolicActor** contract and use it as such a **mock**:
```solidity
SymbolicActor[] mocks;
vm.startPrank(getConfigurer());
mocks = halmosHelpersGetSymbolicActorArray(1);
...
// An example of how a symbolic mock can be used for a given target.
// Obviously, each usage will be different.
targetContract = new TargetContract(address(mocks[0]));
```
See [this](https://github.com/igorganich/halmos-helpers-examples/blob/main/examples/realworld/size-solidity-cantina-audit-reproduce/README.md) realworld example.
## General configurations
### noDuplicateCalls mode
There is a possibility to optimize stateful symbolic execution by eliminating the possibility of symbolic call of the same target function twice in the same path. It is based on the fact that in the real world, it is often enough to call each of the buggy functions only once to see the presence of a bug. Therefore, this mode can save us resources. This is relevant for scenarios with multiple symbolic transactions or with callbacks processing.  Just use `halmosHelpersSetNoDuplicateCalls()` during configuration. The only boolean parameter is to enable or disable this mode:
```solidity
vm.startPrank(getConfigurer()); // Start prank on behalf of configurer
halmosHelpersSetNoDuplicateCalls(true);
vm.stopPrank(); // Stop prank
```
Default setting is `false`.

See [this](https://github.com/igorganich/halmos-helpers-examples/tree/main/examples/coverage/08_no_duplicate_calls) example.
### Verbose mode
To better track the symbolic testing process, a **verbose mode** has been added. Currently, it simply prints information to the **console** about where and which function is currently being called symbolically. This helps somewhat, for example, to catch **bottlenecks** during symbolic execution, but in the future this functionality should be reworked into something more informative.
```solidity
vm.startPrank(getConfigurer()); // Start prank on behalf of configurer
halmosHelpersSetVerboseMode(true);
vm.stopPrank(); // Stop prank
```
## Symbolic offset error in target bypass
There is also a somewhat unusual use of the functionality of this library. Consider [this](https://github.com/igorganich/halmos-helpers-examples/tree/main/examples/coverage/10_handle_abstract_call) example:
```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

contract HandleAbstractCallTarget_original {
    bool public goal;

    constructor() {
        goal = false;
    }

    function entry(address target, bytes calldata data) external {
        target.call(data);
    }

    function goal_function(address target, bytes calldata data) external {
        if (msg.sender != address(this)) {
            revert();
        }
        if (bytes4(data) != bytes4(0x13371337)) {
            revert();
        }
        goal = true;
    }
}
```
The current version of halmos (`0.3.0` at the time of writing) is unable to find a transaction that would make the variable `goal=true` without serious hint.

Any path that tries to call the `goal_function()` function from `entry()` (the only way to succeed) encounters a symbolic offset error:
```javascript
$ halmos --function check_HandleAbstractCall_original
...
[ERROR] check_HandleAbstractCall_original() (paths: 100, time: 1.65s, bounds: [])
WARNING  Encountered symbolic CALLDATALOAD offset: 4 + Extract(7903, 7648, p_data_bytes_d97b804_07)
    (see https://github.com/a16z/halmos/wiki/warnings#internal-error)
WARNING  Encountered symbolic CALLDATALOAD offset: 4 + Extract(7903, 7648, p_data_bytes_d97b804_07)
    (see https://github.com/a16z/halmos/wiki/warnings#internal-error)
WARNING  Encountered symbolic CALLDATALOAD offset: 4 + Extract(7903, 7648, p_data_bytes_d97b804_07)
    (see https://github.com/a16z/halmos/wiki/warnings#internal-error)
WARNING  Encountered symbolic CALLDATALOAD offset: 4 + Extract(7903, 7648, p_data_bytes_d97b804_07)
    (see https://github.com/a16z/halmos/wiki/warnings#internal-error)
Symbolic test result: 0 passed; 1 failed; time: 1
```
The problem is that halmos does not handle such abstract calls inside target contracts well:
```solidity
function entry(address target, bytes calldata data) external {
    target.call(data);
}
```
An imperfect, but in practice quite effective way to solve this problem is to replace the target contract with a slightly modified pseudo-copy. You need to make it inherited from HalmosHelpersTargetsExecutor and replace this abstract call with `executeSymbolicallyTarget(target)`:
```solidity
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.25;

import "halmos-helpers-lib/HalmosHelpersTargetsExecutor.sol";

contract HandleAbstractCallTarget_handle is HalmosHelpersTargetsExecutor {
    bool public goal;

    constructor() {
        goal = false;
    }

    function entry(address target, bytes calldata data) external {
        //target.call(data);
        executeSymbolicallyTarget(target);
    }

    function goal_function(address target, bytes calldata data) external {
        if (msg.sender != address(this)) {
            revert();
        }
        if (bytes4(data) != bytes4(0x13371337)) {
            revert();
        }
        goal = true;
    }
}
```
```javascript
$ halmos --function check_HandleAbstractCall_handle
...
Counterexample:
halmos_ETH_val_uint256_1d2fd96_12 = 0x00
halmos_ETH_val_uint256_5a82ed2_02 = 0x00
halmos_GlobalStorage_selector_bytes4_27f98cf_03 = 0x97be940c
halmos_GlobalStorage_selector_bytes4_e8c649c_13 = 0x99ba5796
halmos_check_HandleAbstractCall_handle_address_705242d_01 = 0xaaaa0002
p_data_bytes_5efc0c3_20 = 0x13371337000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
p_data_length_8f68914_21 = 0x400
p_data_length_bdac19a_08 = 0x400
p_target_address_62f178d_19 = 0x00
p_target_address_d167c22_06 = 0xaaaa0002
...
```
now we are starting to see valid counterexamples. 

Important point: this approach should be used with `halmosHelpersSetNoDuplicateCalls(true)` mode, otherwise there is a high probability of getting into recursion.

It is also worth noting that we simply start ignoring the data passed to the function, which can affect the validity of counterexamples.

This is just one of many possible examples of non-obvious uses of this library within target contracts. I'll probably add other examples later.

I expect the halmos development team to fix **symbolic offset errors** in the future, so I consider this approach as a temporary crutch.
## Plans for improvement
1. Functionality to improve `delegatecall` handling
2. Automatic processing of proxy contracts
3. Implementing other heuristics for finding bugs
4. Optimized flashLoans functionality
5. Optimized multicall handling
## Public use of halmos-helpers-lib
This is a partial list of protocols that use **halmos-helpers-lib** in its test suite:
* [SizeCredit](https://github.com/SizeCredit/size-solidity/tree/main/test/halmos)
* Someday this list will definitely be bigger :D
## License
This code is licensed under [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html).
