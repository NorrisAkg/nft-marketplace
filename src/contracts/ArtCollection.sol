// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

error ArtCollection__Max_Supply_Reached();
error ArtCollection__Not_Enough_Eth_To_Mint(uint256 minimalEthToMint);

contract ArtCollection is ERC721URIStorage, Ownable {
    uint256 private constant TOKEN_MINT_PRICE_IN_ETH = 0.01 ether;
    uint256 private constant TOKEN_MAX_SUPPLY = 1000;
    string private baseTokenURI;
    uint256 private lastTokenId = 0;
    bool private revealed = false;

    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        string memory _baseTokenUri
    ) ERC721(tokenName, tokenSymbol) Ownable(msg.sender) {
        baseTokenURI = _baseTokenUri;
    }

    function mint() public payable {
        if (msg.value < TOKEN_MINT_PRICE_IN_ETH) {
            revert ArtCollection__Not_Enough_Eth_To_Mint(
                TOKEN_MINT_PRICE_IN_ETH
            );
        }
        if (lastTokenId == TOKEN_MAX_SUPPLY) {
            revert ArtCollection__Max_Supply_Reached();
        }
        lastTokenId++;
        _safeMint(msg.sender, lastTokenId);
    }

    function reveal(string memory newBaseURI) public onlyOwner {
        baseTokenURI = newBaseURI;
        revealed = true;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return
            revealed
                ? string.concat(baseTokenURI, Strings.toString(tokenId))
                : baseTokenURI;
    }

    function withdraw() public onlyOwner {
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        require(success, "Transfer failed");
    }
}
