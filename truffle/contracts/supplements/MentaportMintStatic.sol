//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "../main/MentaportERC721.sol";
/**                                            
       
             ___           ___           ___                         ___           ___         ___           ___                   
     /\  \         /\__\         /\  \                       /\  \         /\  \       /\  \         /\  \                  
    |::\  \       /:/ _/_        \:\  \         ___         /::\  \       /::\  \     /::\  \       /::\  \         ___     
    |:|:\  \     /:/ /\__\        \:\  \       /\__\       /:/\:\  \     /:/\:\__\   /:/\:\  \     /:/\:\__\       /\__\    
  __|:|\:\  \   /:/ /:/ _/_   _____\:\  \     /:/  /      /:/ /::\  \   /:/ /:/  /  /:/  \:\  \   /:/ /:/  /      /:/  /    
 /::::|_\:\__\ /:/_/:/ /\__\ /::::::::\__\   /:/__/      /:/_/:/\:\__\ /:/_/:/  /  /:/__/ \:\__\ /:/_/:/__/___   /:/__/     
 \:\~~\  \/__/ \:\/:/ /:/  / \:\~~\~~\/__/  /::\  \      \:\/:/  \/__/ \:\/:/  /   \:\  \ /:/  / \:\/:::::/  /  /::\  \     
  \:\  \        \::/_/:/  /   \:\  \       /:/\:\  \      \::/__/       \::/__/     \:\  /:/  /   \::/~~/~~~~  /:/\:\  \    
   \:\  \        \:\/:/  /     \:\  \      \/__\:\  \      \:\  \        \:\  \      \:\/:/  /     \:\~~\      \/__\:\  \   
    \:\__\        \::/  /       \:\__\          \:\__\      \:\__\        \:\__\      \::/  /       \:\__\          \:\__\  
     \/__/         \/__/         \/__/           \/__/       \/__/         \/__/       \/__/         \/__/           \/__/  
       
       
                                          
**/

/**
 * @title MentaportMint
 * @dev Extending MentaportERC721 with static assets
   Adds functionality to check rules of who, when and where user can mint NFT
**/

contract MentaportMintStatic is MentaportERC721 {

  using Strings for uint256;

  // variables for contracts using static assets
  string public notRevealedUri;
  string public baseURI;
  bool public revealed;

  mapping(bytes => bool) internal _usedMintSignatures;
  bool public useMintRules = true;
  address internal initMentaportAccount = 0x163f3475D1C4F194BD381B230a543DAA8D3f7c0d;

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _initNotRevealedUri,
    uint256 _maxSupply,
    address _admin,
    address _minter,
    address _signer
    ) MentaportERC721(_name, _symbol, _maxSupply, true, _admin, _minter, _signer,initMentaportAccount)
  {
    setBaseURI(_initNotRevealedUri);
    setNotRevealedURI(_initNotRevealedUri);
  }

  //----------------------------------------------------------------------------
  // External functions
  /**
  * @dev Mint function as in {ERC721}
  *
  *   - Follows `mintCompliance` from {MentaportERC721}
  *   - Checks if the contact is using mint rules, if it is it will fail and
  *       let caller know to use `MintMenta` instead.
  *
  */
  function mint(uint256 _mintAmount)
    virtual 
    external 
    payable
    nonReentrant
    whenNotPaused()
    mintCompliance(msg.sender, msg.value, _mintAmount) 
  {
    require(!useMintRules, "Failed using mint rules, use mintMenta.");

    _mintLoop(msg.sender, _mintAmount);
  }

 /**
  * @dev mintLocation function controls signature of rules being passed
  *
  *   - Follows `mintCompliance` from {MentaportERC721}
  *   - Checks `onlyValidMessage` 
  *       - signature approves time / location rule passed
  *   - Checks that the signature ahsnt been used before
  */
  function mintLocation(uint256 _mintAmount, uint256 _rule, uint _timestamp, bytes memory _signature)
    virtual
    external
    payable
    nonReentrant
    whenNotPaused()
    mintCompliance(msg.sender, msg.value, _mintAmount)
    onlyValidMessage(_timestamp,_rule,_signature)
  {
    require(useMintRules, "Not using mint rules, use normal mintStatic function.");
    
    require(_checkMintSignature(_signature), "Signature already used, not valid anymore.");
    
    _mintLoop(msg.sender, _mintAmount);
  }

  /**
  * @dev MINTER_ROLE of contract mints `_mintAmount` of tokens for address `_receiver`
  *
  *  - Emits a {MintForAddress} event.
  */
  function mintForAddress(uint256 _mintAmount, address _receiver)
    virtual
    external 
    nonReentrant 
    mintCompliance(msg.sender, cost, 1)
    onlyMinter {
    
    _mintLoop(_receiver, _mintAmount);

    emit MintForAddress(msg.sender, _mintAmount, _receiver);
  }

  //----------------------------------------------------------------------------
  // Public Only Admin 
  /**
  * @dev reveals URI for static asset contracts
  *
  *  - Emits a {Reveal} event.
  */
  function reveal() virtual external  whenNotPaused() onlyContractAdmin {
    require(isStaticAssets, "Only for Static asset contracts");
    revealed = true;
    emit Reveal(msg.sender);
  }

  /**
  * @dev Set not revealed URI of tokens by Admin
  */
  function setNotRevealedURI(string memory _notRevealedURI) public onlyContractAdmin {
    require(isStaticAssets, "Only for Static asset contracts");
    notRevealedUri = _notRevealedURI;
  }
  /**
  * @dev Set base URI of tokens by Admin
  */
  function setBaseURI(string memory _newBaseURI) public onlyContractAdmin {
    require(isStaticAssets, "Only for Static asset contracts");
    baseURI = _newBaseURI;
  }

  //----------------------------------------------------------------------------
  // External Only Admin / owner
 /**
  * @dev Set use of mint rules in contracty 
  *  Owner con contract can turn off / on the use of mint rules only
  *  
  *  - Emits a {RuleUpdate} event.
  */
  function useUseMintRules(bool _state) external onlyOwner {
    useMintRules = _state;
    uint state = useMintRules ? uint(1) : uint(0);

    emit RuleUpdate(msg.sender, string.concat("Setting mint rules: ",state.toString()));
  }
  //----------------------------------------------------------------------------
  // Internal Functions
  function _checkMintSignature(bytes memory _signature) internal returns (bool) {
    require(!_usedMintSignatures[_signature], "Signature already used, not valid anymore.");

    _usedMintSignatures[_signature] = true;
    return true;
  }

  /**
  * @dev Internal base URI of contract
  */
  function _baseURI() internal view virtual override returns (string memory) {
    return baseURI;
  }
  
}
