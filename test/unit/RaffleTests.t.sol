//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract RaffleTests is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    //this makeAddr is used to create a mock address cheat code in foundry
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deplyer = new DeployRaffle();
        (raffle, helperConfig) = deplyer.deployContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertIfYouDontPayEnough() public {
        vm.prank(PLAYER);

        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        raffle.enterRaffle{value: entranceFee}();
        //Assert
        address playerRecord = raffle.getPlayer(0);
        assert(playerRecord == PLAYER);
    }

    function testEnteringRaffleEmitEvent() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        //Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileCalculating() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // chanes the timestamp of the blockchain
        vm.roll(block.number + 1); //it changes the blockchain number

        //this will fail if we do not have a consumer, in the VRFCoordinatorV2_5Mock we can see the onlyValidConsumer function
        //and since we do not have consumer it will fail for those we need to create subscription, fund subscription and add consumer
        //which we did in the Interactions.s.sol (https://docs.chain.link/vrf/v2-5/subscription/create-manage)
        raffle.performUpkeep("");
        //Act/assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        //Arrange

        vm.warp(block.timestamp + interval + 1); // chanes the timestamp of the blockchain
        vm.roll(block.number + 1); //it changes the blockchain number
        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //Assert
        assert(!upkeepNeeded);
    }

    function testChackUpkeepReturnsFalseIfRaffleIsNotOpen() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // chanes the timestamp of the blockchain
        vm.roll(block.number + 1); //it changes the blockchain number
        raffle.performUpkeep(""); // and this will close the raffle

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //Assert
        assert(!upkeepNeeded);
    }
}
