// SPDX-License-Identifier: UNLICENSED
// @author st4rgard3n, Mr Deadce11, Anirudh Nair
pragma solidity >=0.8.4 <0.9.0;

import '../../lib/solmate/src/tokens/ERC721.sol';
import '../../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol';
import '../../lib/openzeppelin-contracts/contracts/utils/Context.sol';
import '../../lib/openzeppelin-contracts/contracts/utils/Strings.sol';
import '../interfaces/ILensHub.sol';

contract JailBreaker is ERC721, Context {
  using ECDSA for bytes32;
  using Strings for uint256;

  string public baseURI;

  address public authorized;

  address public lensHubAddress;

  uint256 public totalSupply = 1;

  mapping(bytes32 => uint256) internal hashHandles;
  // @notice maps the liberateTokenId => lensProfileId, non-zero value means the liberate token is locked to the lens profile.
  mapping(uint256 => uint256) public lockedId;
  // @notice emits an event that contains tokenId and hash of the twitter handle

  event TokenMinted(uint256 tokenId, bytes32 hashHandle);

  constructor() ERC721('Liberate', 'FREED') {
    authorized = _msgSender();
  }

  // @notice modifier only allows authorized user to call function
  modifier onlyOwner() {
    require(_msgSender() == authorized, 'Only owner!');
    _;
  }

  // @notice returns the token URI of a given token
  // @params the token's id
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), 'Token must exist!');

    string memory currentBaseURI = _baseURI();

    return bytes(baseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, tokenId.toString())) : '';
  }

  /**
   * @dev Returns whether `tokenId` exists.
   *
   * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
   *
   * Tokens start existing when they are minted (`_mint`),
   * and stop existing when they are burned (`_burn`).
   */
  function _exists(uint256 tokenId) internal view virtual returns (bool) {
    return ownerOf(tokenId) != address(0);
  }

  // @notice change the base token URI
  function setBaseURI(string memory newBaseURI) public onlyOwner {
    baseURI = newBaseURI;
  }

  // @notice get the base token URI
  function _baseURI() internal view returns (string memory) {
    return baseURI;
  }

  function handleToTokenId(string calldata handleString) public view returns (uint256) {
    bytes32 hashHandle = keccak256(abi.encodePacked(handleString));
    return hashHandles[hashHandle];
  }

  function setOwner(address newOwner) public onlyOwner {
    authorized = newOwner;
  }

  function getTotalSupply() public view returns (uint256) {
    return totalSupply - 1;
  }

  function mint(string memory handleString, address user) public {
    bytes32 hashHandle = keccak256(abi.encodePacked(handleString));

    require(hashHandles[hashHandle] == 0, 'Profile already exists');

    hashHandles[hashHandle] = totalSupply;

    _mint(user, totalSupply);

    totalSupply += 1;

    emit TokenMinted(hashHandles[hashHandle], hashHandle);
  }

  function transferFrom(address from, address to, uint256 id) public override onlyOwner {
    require(from == _ownerOf[id], 'WRONG_FROM');

    require(to != address(0), 'INVALID_RECIPIENT');

    require(msg.sender == from || isApprovedForAll[from][msg.sender] || msg.sender == getApproved[id], 'NOT_AUTHORIZED');

    // Underflow of the sender's balance is impossible because we check for
    // ownership above and the recipient's balance can't realistically overflow.
    unchecked {
      _balanceOf[from]--;

      _balanceOf[to]++;
    }

    _ownerOf[id] = to;

    delete getApproved[id];

    emit Transfer(from, to, id);
  }

  //@notice set lenshubAddress
  function setLensHubAddress(address _lensHubAddress) external onlyOwner {
    lensHubAddress = _lensHubAddress;
  }

  function profileOwnerOf(uint256 _lensProfileId) public view returns (address owner) {
    owner = ILensHub(lensHubAddress).ownerOf(_lensProfileId);
  }

  function profileIdOfAddress(address lensProfileAddress) public view returns (uint256 lensProfileId) {
    lensProfileId = ILensHub(lensHubAddress).defaultProfile(lensProfileAddress);
  }

  function lockProfile(uint256 liberateTokenId, uint256 lensProfileId) external {
    //get owner of lensprofile
    address lensOwner = profileOwnerOf(lensProfileId);

    require(lockedId[liberateTokenId] == 0, 'cannot lock an already locked token');
    require(_msgSender() == lensOwner, 'Only the Lens Profile owner can liberate their data');

    lockedId[liberateTokenId] = lensProfileId;
  }

  function ownerOf(uint256 liberateTokenId) public view override returns (address) {
    if (lockedId[liberateTokenId] != 0) {
      return ILensHub(lensHubAddress).ownerOf(lockedId[liberateTokenId]);
    } else {
      return _ownerOf[liberateTokenId];
    }
  }
}
