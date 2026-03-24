// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MarketPlace, MarketPlace__Not_the_token_owner, MarketPlace__Token_Not_listed_yet, MarketPlace__Not_enough_ETH_to_buy_token} from "src/contracts/Marketplace.sol";
import {ArtCollection, ArtCollection__Max_Supply_Reached, ArtCollection__Not_Enough_Eth_To_Mint} from "src/contracts/ArtCollection.sol";

contract MarketPlaceTest is Test {
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
        deal(user, baseUserEthBalance);
        vm.prank(user);
        artCollection.mint{value: ethAmount}();
    }

    function testListing() external {
        _mint(bob, 0.1 ether);

        uint256 tokenId = 1;
        uint256 price = 0.2 ether;

        vm.expectEmit(true, true, false, false, address(marketplace));
        emit MarketPlace.NFTListed(tokenId, bob, price);
        vm.prank(bob);
        marketplace.listNFT(tokenId, price);

        (address seller, uint256 listingPrice) = marketplace.getListingInfos(
            tokenId
        );

        assertEq(marketplace.getTokenOwner(tokenId), bob);
        assertEq(seller, bob);
        assertEq(listingPrice, price);
    }

    function testListingFailsIfNotTheTokenOwner() external {
        _mint(bob, 0.1 ether);

        uint256 tokenId = 1;
        uint256 price = 0.2 ether;

        vm.expectRevert(
            abi.encodeWithSelector(
                MarketPlace__Not_the_token_owner.selector,
                tokenId,
                alice
            )
        );
        vm.prank(alice);
        marketplace.listNFT(tokenId, price);
    }

    function testCancelListing() external {
        _mint(alice, 0.1 ether);
        uint256 tokenId = 1;

        vm.prank(alice);
        marketplace.listNFT(tokenId, 0.2 ether);

        vm.expectEmit(true, false, false, false, address(marketplace));
        emit MarketPlace.ListingCanceled(tokenId);
        vm.prank(alice);
        marketplace.cancelListing(tokenId);

        (address seller, uint256 listingPrice) = marketplace.getListingInfos(
            tokenId
        );

        assertEq(seller, address(0));
        assertEq(listingPrice, 0);
    }

    function testCancelListingFailsIfTokenNotListed() external {
        _mint(alice, 0.1 ether);
        uint256 tokenId = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                MarketPlace__Token_Not_listed_yet.selector,
                tokenId
            )
        );
        vm.prank(alice);
        marketplace.cancelListing(tokenId);
    }

    function testNftBuying() external {
        _mint(alice, 0.1 ether); // Alice mint the token
        uint256 aliceStartingBalance = alice.balance;
        uint256 marketplaceStartingBalance = address(marketplace).balance;
        uint256 tokenId = 1;
        uint256 listingPrice = 0.2 ether;

        // Make Alice list token
        vm.prank(alice);
        marketplace.listNFT(tokenId, listingPrice);

        // Make Alice approve marketplace to transfer his tokens
        vm.prank(alice);
        artCollection.setApprovalForAll(address(marketplace), true);

        // Make bob buy token
        deal(bob, 1 ether);
        vm.prank(bob);
        vm.expectEmit(true, true, true, false, address(marketplace));
        emit MarketPlace.TokenOwnershipTransfered(
            tokenId,
            alice,
            bob,
            listingPrice
        );
        marketplace.buyNFT{value: listingPrice}(tokenId);

        // Compute Royalties
        uint256 royaltiesAmount = marketplace.computeRoyaltiesAmount(
            listingPrice
        );

        assertEq(
            alice.balance,
            aliceStartingBalance + (listingPrice - royaltiesAmount)
        );
        assertEq(
            address(marketplace).balance,
            marketplaceStartingBalance + royaltiesAmount
        );
    }

    function testNftBuyingFailsWithoutEnoughEth() external {
        _mint(alice, 0.1 ether); // Alice mint the token
        uint256 tokenId = 1;
        uint256 listingPrice = 0.2 ether;

        // Make Alice list token
        vm.prank(alice);
        marketplace.listNFT(tokenId, listingPrice);

        // Make Alice approve marketplace to transfer his tokens
        vm.prank(alice);
        artCollection.setApprovalForAll(address(marketplace), true);

        // Make bob buy token
        deal(bob, 1 ether);
        vm.expectRevert(
            abi.encodeWithSelector(
                MarketPlace__Not_enough_ETH_to_buy_token.selector,
                tokenId,
                listingPrice
            )
        );
        vm.prank(bob);
        marketplace.buyNFT{value: listingPrice - 10000}(tokenId);
    }
}
