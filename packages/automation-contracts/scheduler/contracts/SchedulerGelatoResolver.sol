// SPDX-License-Identifier: AGPLv3
// solhint-disable not-rely-on-time
pragma solidity ^0.8.0;

import "forge-std/console.sol";

import { IFlowScheduler } from "./interface/IFlowScheduler.sol";
import {
    ISuperToken
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";

contract SchedulerGelatoResolver {

    IFlowScheduler public canonicalScheduler;

    constructor(address _canonicalScheduler) {
        canonicalScheduler = IFlowScheduler(_canonicalScheduler);
    }

    /**
     * @dev Gelato resolver that checks whether Flow Scheduler action can be taken
     * @return bool whether there is a valid Flow Scheduler action to be taken or not
     * @return bytes the function payload to be executed (empty if none)
     */
     function checker(
        address superToken,
        address sender,
        address receiver
    ) external view returns( bool , bytes memory ) {

        IFlowScheduler.FlowSchedule memory flowSchedule = canonicalScheduler.getFlowSchedule(
            superToken, 
            sender, 
            receiver
        );

        // console.log(block.timestamp);             // 1 
        // console.log(flowSchedule.startDate);      // 2
        // console.log(flowSchedule.endDate);        // 3602
        // console.log(flowSchedule.startMaxDelay);  // 60

        if (flowSchedule.endDate != 0 && block.timestamp >= flowSchedule.endDate) {

            // return canExec as true and executeDeleteFlow payload
            return (
                true,
                abi.encodeCall( IFlowScheduler.executeDeleteFlow,
                    (
                        ISuperToken(superToken),
                        sender,
                        receiver,
                        "" // not supporting user data until encoding challenges are solved
                    )
                )
            );

        }

        else if ( flowSchedule.startDate != 0 &&
                  block.timestamp >= flowSchedule.startDate && 
                  block.timestamp <= flowSchedule.startDate + flowSchedule.startMaxDelay) {

            // return canExec as true and executeCreateFlow payload
            return (
                true,
                abi.encodeCall( IFlowScheduler.executeCreateFlow,
                    (
                        ISuperToken(superToken),
                        sender,
                        receiver,
                        "" // not supporting user data until encoding challenges are solved
                    )
                )
            );

        } else {

            return (
                false,
                "0x"
            );

        }

    }

}