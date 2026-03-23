// SPDX-License-Identifier: MIT

import {Test} from "forge-std/Test.sol";
import {ArtCollection} from "src/contracts/ArtCollection.sol";

contract ArtCollectionTest is Test {
    ArtCollection artCollection;

    function setUp() public {
        artCollection = new ArtCollection();
    }
}
