// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ArtCollection, ArtCollection__Max_Supply_Reached, ArtCollection__Not_Enough_Eth_To_Mint} from "src/contracts/ArtCollection.sol";
import {MarketPlace} from "src/contracts/Marketplace.sol";

contract ArtCollectionTest is Test {
    ArtCollection artCollection;
    MarketPlace marketplace;

    uint256 baseUserEthBalance = 10 ether;
    address alice = makeAddr("Alice");
    address jon = makeAddr("Jon");
    address bob = makeAddr("Bob");
    address owner = makeAddr("owner");

    function setUp() public {
        vm.prank(owner);
        artCollection = new ArtCollection(
            "My collection",
            "MCT",
            "ipfs://bafybeict2kq6gt4ikgulypt7h7nwj4hmfi2kevrqvnx2osibfulyy5x3hu/no-time-to-explain.jpeg"
        );
        marketplace = new MarketPlace(address(artCollection));
    }

    function _mint(address user, uint256 ethAmount) private {
        vm.prank(user);
        deal(user, baseUserEthBalance);
        artCollection.mint{value: ethAmount}();
    }

    // modifier minted(string memory _name, uint256 ethAmount) {
    //     _mint(_name, ethAmount);
    //     _;
    // }

    function testMintingSuccess() external {
        uint256 artCollectionStartingBalance = address(artCollection).balance;
        _mint(alice, 0.1 ether);
        uint256 artCollectionEndingBalance = address(artCollection).balance;

        assertEq(artCollection.getLastTokenId(), 1);
        assertEq(
            artCollectionEndingBalance,
            artCollectionStartingBalance + 0.1 ether
        );
    }

    function testMintFailsWithoutEnoughEth() external {
        uint256 mintingValue = 0.008 ether;
        vm.expectRevert(
            abi.encodeWithSelector(
                ArtCollection__Not_Enough_Eth_To_Mint.selector,
                artCollection.getMinimumMintingPrice()
            )
        );
        _mint(alice, mintingValue);
    }

    function testMintFailedAfterMaxSupplyReached() external {
        vm.store(
            address(artCollection),
            bytes32(uint256(9)),
            bytes32(uint256(1000))
        );

        vm.expectRevert(ArtCollection__Max_Supply_Reached.selector);
        artCollection.mint{value: 0.1 ether}();
    }

    function testReveal() external {
        string
            memory newUri = "ipfs://bafybeict2kq6gt4ikgulypt7h7nwj4hmfi2kevrqvnx2osibfulyy5x3hu/time-to-explain.jpeg";

        vm.prank(owner);
        artCollection.reveal(newUri);

        assertEq(artCollection.getRevealStatus(), true);
        assertEq(
            keccak256(bytes(artCollection.getBaseTokenUri())),
            keccak256(bytes(newUri))
        );
    }

    function testWithdraw() external {
        uint256 ownerStartingBalance = owner.balance;
        _mint(alice, 0.1 ether);

        uint256 artCollectionBalanceAfterMinting = address(artCollection)
            .balance;

        vm.prank(owner);
        artCollection.withdraw();

        uint256 ownerEndingBalance = owner.balance;
        uint256 artCollectionEndingBalance = address(artCollection).balance;

        assertEq(
            ownerEndingBalance,
            ownerStartingBalance + artCollectionBalanceAfterMinting
        );
        assertEq(artCollectionEndingBalance, 0);
    }

    function testWithdrawFailsIfNotTheOwner() external {
        _mint(alice, 0.1 ether);

        vm.expectRevert();
        vm.prank(alice);
        artCollection.withdraw();
    }
}
