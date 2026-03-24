// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

error MarketPlace__Not_the_token_owner(uint256 tokenId, address lister);
error MarketPlace__Price_must_be_greather_than_zero();
error MarketPlace__Token_Not_listed_yet(uint256 tokenId);
error MarketPlace__Not_enough_ETH_to_buy_token(
    uint256 tokenId,
    uint256 tokenPrice
);
error MarketPlace__Failed_to_send_ETH();

contract MarketPlace is ReentrancyGuard {
    event NFTListed(
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );
    event ListingCanceled(uint256 indexed tokenId);
    event TokenOwnershipTransfered(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        uint256 priceCost
    );

    struct Listing {
        address seller;
        uint256 listingPrice;
    }

    uint256 private constant ROYALTIES_RATIO_PER_THOUSAND = 25; // 2.5 %
    mapping(uint256 tokenId => Listing tokenListing) public tokenListingInfos;
    IERC721 private immutable COLLECTION_CONTRACT;

    constructor(address _collectionContract) {
        COLLECTION_CONTRACT = IERC721(_collectionContract);
    }

    function _onLyTokenOwner(uint256 tokenId) internal view {
        if (COLLECTION_CONTRACT.ownerOf(tokenId) != msg.sender) {
            revert MarketPlace__Not_the_token_owner(tokenId, msg.sender);
        }
    }

    function _tokenListed(uint256 tokenId) internal view {
        if (tokenListingInfos[tokenId].seller == address(0)) {
            revert MarketPlace__Token_Not_listed_yet(tokenId);
        }
    }

    modifier onLyTokenOwner(uint256 tokenId) {
        _onLyTokenOwner(tokenId);
        _;
    }

    modifier tokenListed(uint256 tokenId) {
        _tokenListed(tokenId);
        _;
    }

    function listNFT(
        uint256 tokenId,
        uint256 price
    ) public onLyTokenOwner(tokenId) {
        // Vérifier si le msg.sender est bien le propriétaire du token
        if (price == 0) {
            revert MarketPlace__Price_must_be_greather_than_zero();
        }

        Listing memory listing = Listing({
            seller: msg.sender,
            listingPrice: price
        });

        tokenListingInfos[tokenId] = listing;

        emit NFTListed(tokenId, msg.sender, price);
    }

    function cancelListing(
        uint256 tokenId
    ) public onLyTokenOwner(tokenId) tokenListed(tokenId) {
        delete tokenListingInfos[tokenId];

        emit ListingCanceled(tokenId);
    }

    function sendEther(address _to, uint256 _amount) private {
        (bool sent, ) = payable(_to).call{value: _amount}("");
        if (!sent) {
            revert MarketPlace__Failed_to_send_ETH();
        }
    }

    function computeRoyaltiesAmount(
        uint256 amount
    ) public pure returns (uint256) {
        return (amount * ROYALTIES_RATIO_PER_THOUSAND) / 1000;
    }

    // nonReentrant + CEI pattern applied — reentrancy warning is a false positive
    function buyNFT(
        uint256 tokenId
    ) public payable tokenListed(tokenId) nonReentrant {
        uint256 listingPrice = tokenListingInfos[tokenId].listingPrice;
        address tokenOwner = COLLECTION_CONTRACT.ownerOf(tokenId);
        if (msg.value < listingPrice) {
            revert MarketPlace__Not_enough_ETH_to_buy_token(
                tokenId,
                listingPrice
            );
        }

        delete (tokenListingInfos[tokenId]);
        COLLECTION_CONTRACT.safeTransferFrom(tokenOwner, msg.sender, tokenId); // Transfer token ownership

        uint256 royaltiesValue = computeRoyaltiesAmount(msg.value);
        sendEther(tokenOwner, msg.value - royaltiesValue);

        emit TokenOwnershipTransfered(
            tokenId,
            tokenOwner,
            msg.sender,
            msg.value
        );
    }

    // Getters

    function getTokenOwner(uint256 tokenId) public view returns (address) {
        return COLLECTION_CONTRACT.ownerOf(tokenId);
    }

    function getListingInfos(
        uint256 tokenId
    ) public view returns (address seller, uint256 price) {
        Listing memory listing = tokenListingInfos[tokenId];
        return (listing.seller, listing.listingPrice);
    }
}
