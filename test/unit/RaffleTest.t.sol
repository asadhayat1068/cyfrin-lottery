// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    event RaffleEntered(address indexed player);
    event RaffleWinner(address indexed winner, uint256 timestamp);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializedInOpenState() public view {
      assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWithInsufficientEntranceFee() public {
      // Arrange
      vm.prank(PLAYER);
      // Act/Assert
      vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
      raffle.enterRaffle();
    }

    function testRaffleRecordsPlaterEntry() public {
      // Arrange
      vm.prank(PLAYER);
      // Act
      raffle.enterRaffle{value: entranceFee}();
      address playerAddress = raffle.getPlayer(0);
      // Assert
      assert(playerAddress == PLAYER);
    }

    function testEnterRaffleEmitsEvent() public {
      // Arrange
      vm.prank(PLAYER);
      // Act
      vm.expectEmit(true, false, false, false, address(raffle));
      emit RaffleEntered(PLAYER);
      // Assert
      raffle.enterRaffle{value: entranceFee}();
    }

    function testEnterRaffleRevertsWhenRaffleIsCalculating() public {
      // Arrange
      vm.prank(PLAYER);
      raffle.enterRaffle{value: entranceFee}();
      vm.warp(block.timestamp+interval+1);
      vm.roll(block.number+1);
      raffle.performUpkeep("");
      // Act/Assert
      vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
      vm.prank(PLAYER);
      raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpKeepReturnsFalseIfRaffleHasNoBalance() public {
      // Arrange
      vm.warp(block.timestamp+interval+1);
      vm.roll(block.number+1);

      // Act
      (bool upKeepNeeded, ) = raffle.checkUpkeep("");

      // Assert
      assert(!upKeepNeeded);

    }

    function testCheckUpKeepReturnsFalseIfRaffleIsNotOpen() public {
      // Arrange
      vm.prank(PLAYER);
      raffle.enterRaffle{value: entranceFee}();
      vm.warp(block.timestamp+interval+1);
      vm.roll(block.number+1);
      raffle.performUpkeep("");
      // Act
      (bool upKeepNeeded, ) = raffle.checkUpkeep("");

      // Assert
      assert(!upKeepNeeded);
    }

    // Perform Upkeep

    function testPerformUpkeepCanOnlyRunIfCheckUpKeepIsTrue() public {
      // Arrange
      vm.prank(PLAYER);
      raffle.enterRaffle{value: entranceFee}();
      vm.warp(block.timestamp+interval+1);
      vm.roll(block.number+1);

      // Act/Assert
      raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpKeepIsFalse() public {
      // Arrange
      uint256 currentBalance = 0;
      uint256 playerCount = 0;
      Raffle.RaffleState raffleState = raffle.getRaffleState();

      raffle.enterRaffle{value: entranceFee}();
      currentBalance = currentBalance + entranceFee;
      playerCount = playerCount + 1;

      // Act/Assert
      vm.expectRevert(
        abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, playerCount, uint256(raffleState))
      );
      raffle.performUpkeep("");

    }

    modifier raffleEntered {
      vm.prank(PLAYER);
      raffle.enterRaffle{value: entranceFee}();
      vm.warp(block.timestamp+interval+1);
      vm.roll(block.number+1);
      _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
      // Arrange
      // Act
      vm.recordLogs();
      raffle.performUpkeep("");
      Vm.Log[] memory enteries = vm.getRecordedLogs();

      Raffle.RaffleState raffleState = raffle.getRaffleState();
      uint256 requestId = abi.decode(enteries[0].data, (uint256));

      // Assert
      assert(raffleState == Raffle.RaffleState.CALCULATING_WINNER);
      assert(requestId > 0);
    }

    // FullFill Random words
    // Fuzz Test

    modifier skipFork {
      if (block.chainid != LOCAL_CHAIN_ID) {
        return;
      }
      _;
    }

    function testFullFullRandomWordsCanOnlyBeCalledByPerformUpKeep(uint256 randomRequestId) public raffleEntered skipFork {
      vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
      VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));

    }

    function testFullfillRandomWordsPicksAWinnerResetsAndSendMoney() public raffleEntered skipFork {
      // Arrange
      uint256 additionalEntrants = 3; // 4 total
      uint256 startingIndex = 1;
      for (uint i = startingIndex; i < startingIndex + additionalEntrants; i++) {
        address newPlayer = address(uint160(i));
        hoax(newPlayer, STARTING_PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
      }

      uint256 startingTimeStamp = raffle.getLastTimestamp();
      address expectedWinner = raffle.getPlayer(1);
      uint256 startingWinnerBalance = expectedWinner.balance;
      // Act
      vm.recordLogs();
      raffle.performUpkeep("");
      Vm.Log[] memory enteries = vm.getRecordedLogs();

      uint256 requestId = abi.decode(enteries[0].data, (uint256));
      VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(requestId, address(raffle));
      
      // Assert
      address recentWinner = raffle.getRecentWinner();
      Raffle.RaffleState raffleState = raffle.getRaffleState();
      uint256 winnerBalance = recentWinner.balance;
      uint256 endingTimestamp = raffle.getLastTimestamp();
      uint256 prize = entranceFee * (additionalEntrants + 1);

      assert(recentWinner == expectedWinner);
      assert(raffleState == Raffle.RaffleState.OPEN);
      assert(winnerBalance == startingWinnerBalance + prize);
      assert(endingTimestamp > startingTimeStamp);
    }
}
