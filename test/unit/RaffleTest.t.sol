// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract RaffleTest is Test {
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
}
