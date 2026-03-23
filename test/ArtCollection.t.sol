// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ArtCollection, ArtCollection__Max_Supply_Reached} from "src/contracts/ArtCollection.sol";

contract ArtCollectionTest is Test {
    ArtCollection artCollection;
    uint256 baseUserEthBalance = 10 ether;
    string userName1 = "Alice";
    string userName2 = "Jon";
    string userName3 = "Bob";

    function setUp() public {
        artCollection = new ArtCollection(
            "My collection",
            "MCT",
            "ipfs://bafybeict2kq6gt4ikgulypt7h7nwj4hmfi2kevrqvnx2osibfulyy5x3hu/no-time-to-explain.jpeg"
        );
    }

    function testMintFailedAfterMaxSupplyReached() external {
        address user1 = makeAddr(userName1);
        // uint256 maxSupply = artCollection.getMaxSupply();

        vm.prank(user1);
        vm.mockCall(
            address(artCollection),
            abi.encodeWithSelector(artCollection.getMaxSupply.selector),
            abi.encode(1000)
        );
        vm.store(
            address(artCollection),
            bytes32(uint256(9)),
            bytes32(uint256(1000))
        );
        deal(user1, baseUserEthBalance);

        console.log("total minted", artCollection.getMaxSupply());
        console.log("last token id", artCollection.getLastTokenId());
        vm.expectRevert(ArtCollection__Max_Supply_Reached.selector);
        artCollection.mint{value: 0.1 ether}();
    }
}
