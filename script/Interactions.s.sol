// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract SubscriptionFactory is Script{
  function createSubscriptionUsingConfig() public returns (uint256 subscriptionId, address vrfCoordinator) {
    // HelperConfig helperConfig = new HelperConfig();
    // address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
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

contract FundSubscription is Script, CodeConstants {
  uint256 public constant FUND_AMOUNT = 5 ether; //3 LINK

  function fundSubscriptionUsingConfig() public {
    HelperConfig helperConfig = new HelperConfig();
    address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
    uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
    address linkToken = helperConfig.getConfig().linkToken;
    fundSubscription(vrfCoordinator, subscriptionId, linkToken);
  }

  function fundSubscription(address _vrfCoordinator, uint256 _subscriptionId, address _linkToken) public {
    console2.log("Funding subscription id: ", _subscriptionId);
    console2.log("Funding subscription on chain id: ", block.chainid);
    console2.log("Using vrfCoordinator: ", _vrfCoordinator);
    if (block.chainid == LOCAL_CHAIN_ID) {
      vm.startBroadcast();
      VRFCoordinatorV2_5Mock(_vrfCoordinator).fundSubscription(_subscriptionId, FUND_AMOUNT);
      vm.stopBroadcast();      
    } else {
      vm.startBroadcast();
      LinkToken(_linkToken).transferAndCall(
        _vrfCoordinator,
        FUND_AMOUNT,
        abi.encode(_subscriptionId)
      );
      vm.stopBroadcast();
    }
  }

  function run() public {
    fundSubscriptionUsingConfig();
  }
}

contract AddConsumer is Script, CodeConstants {
  function addConsumerUsingConfig(address recentDeployment) public {
    HelperConfig helperConfig = new HelperConfig();
    address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
    uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
    addConsumer(recentDeployment, vrfCoordinator, subscriptionId);
  }

  function addConsumer(
    address _consumerContract,
    address _vrfCoordinator,
    uint256 _subscriptionId
  ) public {
    console2.log("Adding consumer to VRF Coordinator: ", _vrfCoordinator);
    console2.log("Adding consumer to subscription id: ", _subscriptionId);
    console2.log("Adding consumer to contract: ", _consumerContract);
    console2.log("Adding consumer on chain id: ", block.chainid);
    vm.startBroadcast();
    VRFCoordinatorV2_5Mock(_vrfCoordinator).addConsumer(_subscriptionId, _consumerContract);
    vm.stopBroadcast();
  }

  function run() external {
    address mostRecentlyDeployedContract = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
    addConsumerUsingConfig(mostRecentlyDeployedContract);
  }
}