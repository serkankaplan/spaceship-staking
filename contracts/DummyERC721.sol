//SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract DummyERC721 is ERC721, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
        * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` to the
        * account that deploys the contract.
        *
        * See {ERC20-constructor}.
        */
    constructor() public ERC721("DummyNFT", "DNFT"){
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());

    }

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    function mint(address tokenHolder) public returns (uint256)
    {
        require(hasRole(MINTER_ROLE, _msgSender()), "DummyERC721: must have minter role to mint");
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(tokenHolder, newItemId);
        return newItemId;
    }

    function addMinter(address accountAddress) public
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "DummyERC721: must have admin role to add minter");

        _setupRole(MINTER_ROLE, accountAddress);
    }
}
