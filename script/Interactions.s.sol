// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract SubscriptionFactory is Script{
  function createSubscriptionUsingConfig() public returns (uint256 subscriptionId, address vrfCoordinator) {
    HelperConfig helperConfig = new HelperConfig();
    address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
    subscriptionId = createSubscription(vrfCoordinator);
  }

  function createSubscription(address _vrfCoordinator) public returns(uint256 subscriptionId) {
    console2.log("Creating a subscription on chain id: ", block.chainid);
    vm.startBroadcast();
    subscriptionId = VRFCoordinatorV2_5Mock(_vrfCoordinator).createSubscription();
    vm.stopBroadcast();
    console2.log("Created subscription with id: ", subscriptionId);
  }

  function run() public {
    // Create a subscription
  }
}

contract FundSubscription is Script {
  uint256 public constant FUND_AMOUNT = 5 ether; //3 LINK

  function fundSubscriptionUsingConfig() public {
    HelperConfig helperConfig = new HelperConfig();
    address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
    uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
  }
  function run() public {}
}