// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import { ISuperfluid, FlowOperatorDefinitions } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperfluidFrameworkDeployer, SuperfluidTester, Superfluid, ConstantFlowAgreementV1, CFAv1Library, SuperTokenFactory } from "../test/SuperfluidTester.sol";
import { ERC1820RegistryCompiled } from "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
import { IFlowScheduler } from "./../contracts/interface/IFlowScheduler.sol";
import { FlowScheduler } from "./../contracts/FlowScheduler.sol";
import { SchedulerGelatoResolver } from "./../contracts/SchedulerGelatoResolver.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC1820Registry } from "@openzeppelin/contracts/utils/introspection/IERC1820Registry.sol";


/// @title Example Super Token Test
/// @author ctle-vn, SuperfluidTester taken from jtriley.eth
/// @notice For demonstration only. You can delete this file.
contract SchedulerGelatoResolverTest is SuperfluidTester {

    event FlowScheduleCreated(
        ISuperToken indexed superToken,
        address indexed sender,
        address indexed receiver,
        uint32 startDate,
        uint32 startMaxDelay,
        int96 flowRate,
        uint32 endDate,
        uint256 startAmount,
        bytes userData
    );

    event FlowScheduleDeleted(
        ISuperToken indexed superToken,
        address indexed sender,
        address indexed receiver
    );

    event CreateFlowExecuted(
        ISuperToken indexed superToken,
        address indexed sender,
        address indexed receiver,
        uint32 startDate,
        uint32 startMaxDelay,
        int96 flowRate,
        uint256 startAmount,
        bytes userData
    );

    event DeleteFlowExecuted(
        ISuperToken indexed superToken,
        address indexed sender,
        address indexed receiver,
        uint32 endDate,
        bytes userData
    );

    SuperfluidFrameworkDeployer internal immutable sfDeployer;
    SuperfluidFrameworkDeployer.Framework internal sf;
    ISuperfluid host;
    ConstantFlowAgreementV1 cfa;
    FlowScheduler internal flowScheduler;
    SchedulerGelatoResolver internal gelatoResolver;
    uint256 private _expectedTotalSupply = 0;

    bytes4 constant INVALID_CFA_PERMISSIONS_ERROR_SIG = 0xa3eab6ac;

    /// @dev This is required by solidity for using the CFAv1Library in the tester
    using CFAv1Library for CFAv1Library.InitData;

    constructor() SuperfluidTester(3) {
        vm.startPrank(admin);
        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);
        sfDeployer = new SuperfluidFrameworkDeployer();
        sf = sfDeployer.getFramework();
        host = sf.host;
        cfa = sf.cfa;
        vm.stopPrank();

        /// @dev Example Flow Scheduler to test
        flowScheduler = new FlowScheduler(host, "");

        /// @dev Example SchedulerGelatoResolver to test
        gelatoResolver = new SchedulerGelatoResolver(address(flowScheduler));
    }

    function setUp() public virtual {
        (token, superToken) = sfDeployer.deployWrapperSuperToken("FTT", "FTT", 18, type(uint256).max);

        for (uint32 i = 0; i < N_TESTERS; ++i) {
            token.mint(TEST_ACCOUNTS[i], INIT_TOKEN_BALANCE);

            vm.startPrank(TEST_ACCOUNTS[i]);
            token.approve(address(superToken), INIT_SUPER_TOKEN_BALANCE);
            superToken.upgrade(INIT_SUPER_TOKEN_BALANCE);
            _expectedTotalSupply += INIT_SUPER_TOKEN_BALANCE;
            vm.stopPrank();
        }
    }

    function getHashID(
        address _superToken,
        address sender,
        address receiver
    )
        public pure returns (bytes32)
    {
        return keccak256(abi.encodePacked(
            _superToken,
            sender,
            receiver
        ));
    }

    /// @dev Constants for Testing
    uint32 internal defaultStartDate = uint32(block.timestamp + 1);
    uint32 testNumber;
    int96 defaultFlowRate = int96(1000);
    uint32 defaultStartMaxDelay = uint32(60);
    uint256 defaultStartAmount = 500;

    function testCreateFlowScheduleWithExplicitTimeWindow() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        uint32 defaultEndDate = defaultStartDate + uint32(3600);
        emit FlowScheduleCreated(
            superToken,
            alice,
            bob,
            defaultStartDate,
            defaultStartMaxDelay,
            defaultFlowRate,
            defaultEndDate,
            defaultStartAmount,
            ""
        );
        vm.expectCall(
            address(flowScheduler),
            abi.encodeCall(
                flowScheduler.createFlowSchedule,
                (
                    superToken,
                    bob,
                    defaultStartDate,
                    defaultStartMaxDelay,
                    defaultFlowRate,
                    defaultStartAmount,
                    defaultEndDate,
                    "",
                    ""
                )
            )
        );
        flowScheduler.createFlowSchedule(
            superToken,
            bob,
            defaultStartDate,
            defaultStartMaxDelay,
            defaultFlowRate,
            defaultStartAmount,
            defaultEndDate,
            "",
            ""
        );

        (uint32 startDate,,uint32 endDate,,,) = flowScheduler.flowSchedules(getHashID(address(superToken),alice,bob));
        assertTrue(startDate != 0 || endDate != 0, "Flow schedule not created");
    }

    function testCreateFlowScheduleWithZeroTimes() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        uint32 startMaxDelay = 0;
        uint32 defaultEndDate = 3600;
        emit FlowScheduleCreated(
            superToken,
            alice,
            bob,
            0,
            startMaxDelay,
            defaultFlowRate,
            defaultEndDate,
            defaultStartAmount,
            ""
        );
        vm.expectCall(
            address(flowScheduler),
            abi.encodeCall(
                flowScheduler.createFlowSchedule,
                (
                    superToken,
                    bob,
                    0,
                    startMaxDelay,
                    defaultFlowRate,
                    defaultStartAmount,
                    defaultEndDate,
                    "",
                    ""
                )
            )
        );
        flowScheduler.createFlowSchedule(
            superToken,
            bob,
            0,
            startMaxDelay,
            defaultFlowRate,
            defaultStartAmount,
            defaultEndDate,
            "",
            ""
        );
        (uint32 startDate,,uint32 endDate,,,) = flowScheduler.flowSchedules(getHashID(address(superToken),alice,bob));
        assertTrue(startDate != 0 || endDate != 0, "Flow schedule not created");
    }

    function testCannotCreateFlowScheduleWhenSenderSameAsReceiver() public {
        // Expect revert on receiver same as sender.
        vm.prank(alice);
        vm.expectRevert(IFlowScheduler.AccountInvalid.selector);
        flowScheduler.createFlowSchedule(
            superToken,
            alice,
            defaultStartDate,
            uint32(60),
            defaultFlowRate,
            defaultStartAmount,
            defaultStartDate + uint32(3600),
            "",
            ""
        );
    }

    function testCannotCreateFlowScheduleWhenTimeWindowInvalid() public {
        vm.expectRevert(IFlowScheduler.TimeWindowInvalid.selector);
        flowScheduler.createFlowSchedule(
            superToken,
            bob,
            uint32(0),
            uint32(60),
            int96(1000),
            defaultStartAmount,
            uint32(0),
            "",
            ""
        );
    }

    function testCannotExecuteCreateFlowWhenScheduleDNE() public {

        vm.prank(admin);
        vm.warp(100);

        // Expect unsuccessful execution when schedule does not exist.

        // Expect canExec to be false
        (bool canExec, bytes memory execPayload) = gelatoResolver.checker(address(superToken), bob, alice);
        assertTrue(!canExec);

        // And expect payload to not be executable
        (bool status, ) = address(flowScheduler).call(execPayload);
        assertTrue(!status);

    }

    function testCannotExecuteCreateFlowWithInvalidPermissions() public {
        vm.prank(bob);
        superToken.increaseAllowance(address(flowScheduler), type(uint256).max);
        vm.prank(bob);
        flowScheduler.createFlowSchedule(
            superToken, 
            alice, 
            defaultStartDate, 
            uint32(1000), 
            int96(1000), 
            defaultStartAmount, 
            defaultStartDate + uint32(3600), 
            "", 
            ""
        );

        // vm.expectRevert(0xa3eab6ac); // error CFA_ACL_OPERATOR_NO_CREATE_PERMISSIONS() -> 0xa3eab6ac
        
        vm.warp(defaultStartDate + 1000);
        vm.prank(admin);

        // Get create flow payload and expect it to be executable
        (bool canExec, bytes memory execPayload) = gelatoResolver.checker(address(superToken), bob, alice);
        assertTrue(canExec);

        // And expect payload execution to fail
        (bool success, bytes memory out) = address(flowScheduler).call(execPayload);
        assertTrue(!success);
        assertEq(out, abi.encodePacked(INVALID_CFA_PERMISSIONS_ERROR_SIG), "should error due to wrong acl permissions");
    }

    function testCannotExecuteCreateFlowWhenTimeWindowInvalid() public {
        // Expect revert on when start and end are both 0.
        vm.startPrank(admin);
        // Get create flow payload and expect it to not be executable
        (bool canExec, bytes memory execPayload) = gelatoResolver.checker(address(superToken), alice, bob);
        assertTrue(!canExec);
        assertEq("0x", execPayload, "payload not empty");

    }

    function testExecuteCreateFlow() public {
        vm.startPrank(alice);
        flowScheduler.createFlowSchedule(
            superToken, 
            bob, 
            defaultStartDate, 
            uint32(100), 
            int96(1000), 
            defaultStartAmount, 
            defaultStartDate + uint32(3600), 
            "", 
            ""
        );
        host.callAgreement(
            cfa,
            abi.encodeCall(
                cfa.updateFlowOperatorPermissions,
                (
                superToken,
                address(flowScheduler),
                FlowOperatorDefinitions.AUTHORIZE_FLOW_OPERATOR_CREATE,
                1000,
                new bytes(0)
                )
            ),
            new bytes(0)
        );
        // increase allowance so flowScheduler can transfer tokens from alice to bob
        // when vesting starts
        superToken.increaseAllowance(address(flowScheduler), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit CreateFlowExecuted(
            superToken, alice, bob, defaultStartDate, uint32(100), int96(1000), defaultStartAmount, ""
        );
        vm.warp(100);
        vm.expectCall(
            address(flowScheduler),
            abi.encodeCall(
                flowScheduler.executeCreateFlow,
                (superToken, alice, bob, "")
            )
        );
        FlowScheduler.FlowSchedule memory schedule = flowScheduler.getFlowSchedule(address(superToken), alice, bob);
        assertEq(schedule.startAmount, defaultStartAmount);
        uint256 bobBalanceBefore = superToken.balanceOf(bob);
        uint256 aliceBalanceBefore = superToken.balanceOf(alice);
        
        // Get create flow payload and expect it to be executable
        (bool canExec, bytes memory execPayload) = gelatoResolver.checker(address(superToken), alice, bob);
        assertTrue(canExec);
        // And expect payload execution to succeed
        (bool success, ) = address(flowScheduler).call(execPayload);
        assertTrue(success);
        
        schedule = flowScheduler.getFlowSchedule(address(superToken), alice, bob);
        assertEq(schedule.startAmount, 0);
        // Bob's balance is slightly more than or equal to his previous balance plus defaultStartAmount
        // this is due to the logic which determines the startAmount
        assertTrue(superToken.balanceOf(bob) >= bobBalanceBefore + defaultStartAmount);

        // Alice's balance is less than or equal to previous balance sub defaultStartAmount
        // it is actually slightly less because of the deposit paid for stream creation
        assertTrue(superToken.balanceOf(alice) <= aliceBalanceBefore - defaultStartAmount);
    }

    function testExecute2xCreateFlow() public {
        vm.startPrank(alice);
        flowScheduler.createFlowSchedule(
            superToken, bob, defaultStartDate, uint32(100), int96(1000), 0, defaultStartDate + uint32(3600), "", ""
        );
        host.callAgreement(
            cfa,
            abi.encodeCall(
                cfa.updateFlowOperatorPermissions,
                (
                superToken,
                address(flowScheduler),
                FlowOperatorDefinitions.AUTHORIZE_FLOW_OPERATOR_CREATE,
                1000,
                new bytes(0)
                )
            ),
            new bytes(0)
        );
        // Remove any allowance
        superToken.approve(address(flowScheduler), 0);
        vm.stopPrank();
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit CreateFlowExecuted(
            superToken, alice, bob, defaultStartDate, uint32(100), int96(1000), 0, ""
        );
        vm.warp(100);
        vm.expectCall(
            address(flowScheduler),
            abi.encodeCall(
                flowScheduler.executeCreateFlow,
                (superToken, alice, bob, "")
            )
        );

        FlowScheduler.FlowSchedule memory schedule = flowScheduler.getFlowSchedule(alice, bob, address(superToken));
        assertEq(schedule.startAmount, 0);

        // Get create flow payload and expect it to be executable
        (bool canExec, bytes memory execPayload) = gelatoResolver.checker(address(superToken), alice, bob);
        assertTrue(canExec);
        // And expect payload execution to succeed
        (bool success, ) = address(flowScheduler).call(execPayload);
        assertTrue(success);

        schedule = flowScheduler.getFlowSchedule(address(superToken), alice, bob);
        assertEq(schedule.startAmount, 0);

        // try to execute again
        // Get create flow payload and expect it to not be executable
        ( canExec, execPayload) = gelatoResolver.checker(address(superToken), alice, bob);
        assertTrue(!canExec);
        assertEq("0x", execPayload, "payload not empty");
    }

    function testCreateScheduleAndDeleteSchedule() public {
        vm.startPrank(alice);
        flowScheduler.createFlowSchedule(
            superToken, bob, defaultStartDate, 60, int96(1000), defaultStartAmount, defaultStartDate + uint32(3600), "", ""
        );
        FlowScheduler.FlowSchedule memory schedule1 = flowScheduler.getFlowSchedule(address(superToken), alice, bob);
        assertEq(schedule1.startDate, defaultStartDate);
        vm.expectEmit(true, true, true, true);
        emit FlowScheduleDeleted(superToken, alice, bob);
        flowScheduler.deleteFlowSchedule(superToken, bob, "");
        FlowScheduler.FlowSchedule memory schedule2 = flowScheduler.getFlowSchedule(address(superToken), alice, bob);
        assertEq(schedule2.startDate, 0);
    }

    function testExecuteDeleteFlow() public {

        vm.startPrank(alice);
        flowScheduler.createFlowSchedule(
            superToken, 
            bob, 
            defaultStartDate, 
            uint32(100), 
            int96(1000), 
            defaultStartAmount, 
            defaultStartDate + uint32(3600), // end date = ~3602
            "", 
            ""
        );
        host.callAgreement(
            cfa,
            abi.encodeCall(
                cfa.updateFlowOperatorPermissions,
                (
                superToken,
                address(flowScheduler),
                FlowOperatorDefinitions.AUTHORIZE_FULL_CONTROL ,
                1000,
                new bytes(0)
                )
            ),
            new bytes(0)
        );
        // increase allowance so flowScheduler can transfer tokens from alice to bob
        // when vesting starts
        superToken.increaseAllowance(address(flowScheduler), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(admin);
        vm.expectEmit(true, true, true, true);
        emit CreateFlowExecuted(
            superToken, alice, bob, defaultStartDate, uint32(100), int96(1000), defaultStartAmount, ""
        );
        vm.warp(100);
        vm.expectCall(
            address(flowScheduler),
            abi.encodeCall(
                flowScheduler.executeCreateFlow,
                (superToken, alice, bob, "")
            )
        );
        FlowScheduler.FlowSchedule memory schedule = flowScheduler.getFlowSchedule(address(superToken), alice, bob);
        assertEq(schedule.startAmount, defaultStartAmount);
        uint256 bobBalanceBefore = superToken.balanceOf(bob);
        uint256 aliceBalanceBefore = superToken.balanceOf(alice);
        
        // Get create flow payload and expect it to be executable
        (bool canExec, bytes memory execPayload) = gelatoResolver.checker(address(superToken), alice, bob);
        assertTrue(canExec);
        // And expect payload execution to succeed
        (bool success, ) = address(flowScheduler).call(execPayload);
        assertTrue(success);
        
        schedule = flowScheduler.getFlowSchedule(address(superToken), alice, bob);
        assertEq(schedule.startAmount, 0);
        // Bob's balance is slightly more than or equal to his previous balance plus defaultStartAmount
        // this is due to the logic which determines the startAmount
        assertTrue(superToken.balanceOf(bob) >= bobBalanceBefore + defaultStartAmount);

        // Alice's balance is less than or equal to previous balance sub defaultStartAmount
        // it is actually slightly less because of the deposit paid for stream creation
        assertTrue(superToken.balanceOf(alice) <= aliceBalanceBefore - defaultStartAmount);

        // Advance into flow deletion time
        vm.warp(3650);

        // Expect flow deletion
        vm.expectCall(
            address(flowScheduler),
            abi.encodeCall(
                flowScheduler.executeDeleteFlow,
                (superToken, alice, bob, "")
            )
        );

        // Get create flow payload and expect it to be executable
        (canExec, execPayload) = gelatoResolver.checker(address(superToken), alice, bob);
        assertTrue(canExec);
        // And expect payload execution to succeed
        (success, ) = address(flowScheduler).call(execPayload);
        assertTrue(success);

        // Assert flow rate is zeroed out
        assertEq(
            cfa.getNetFlow(superToken, alice),
            0
        );

    }

}