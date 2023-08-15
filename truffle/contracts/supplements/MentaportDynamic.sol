//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "./MentaportMintStatic.sol";
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
* @title MentaportDynamic
* @dev Extending MentaportMint - MentaportERC721
*
*  Adds functionality to have dynamic state upgrades of NFT tokens with defined rules.
*  Dynamic state starts at 0 - meaning default, nothing has happened apart from revealing URI
*/
contract MentaportDynamic is MentaportMintStatic {
  using Strings for uint256;
  
  string public baseExtension = ".json";
  bool public useDynamicRules = true;
  mapping(uint256 => uint256) internal _tokenState;
  mapping(uint256 => string) internal _stateURI;
  uint256 private _recentStateSet;

  constructor(
    string memory _name,
    string memory _symbol,
    string memory _initNotRevealedUri,
    uint256 _maxSupply,
    address _admin,
    address _minter,
    address _signer
  ) MentaportMintStatic(_name, _symbol, _initNotRevealedUri, _maxSupply, _admin, _minter, _signer) 
  {}

  //----------------------------------------------------------------------------
  // Public Functions
  /**
  * @dev Token URI of token asked
  */
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_exists(tokenId), "MentaportDynamic: URI query for nonexistent token");

    if(!revealed) {
      return notRevealedUri;
    }
    uint256 state = _tokenState[tokenId];
    string memory currentStateURI = _stateURI[state];
    return bytes(currentStateURI).length > 0
      ? string(abi.encodePacked(currentStateURI, tokenId.toString(), baseExtension))
      : "";
  }

  //----------------------------------------------------------------------------
  // External Functions
  /**
  * @dev Recent state set in dynamic contract 
  */
  function recentStateSet() external view returns (uint256)  {
    return _recentStateSet;
  }
  /**
  * @dev Get state of `_tokenId` 
  */
  function getTokenState(uint256 _tokenId) external view returns (uint256) {
    require(_exists(_tokenId), "Failed, request for nonexistent token");
    return  _tokenState[_tokenId];
  }
  /**
  * @dev Get URI of particular `_state` 
  */
  function getURIforState(uint256 _state) external view returns (string memory) {
    return _stateURI[_state];
  }
  //----------------------------------------------------------------------------
  // External Only ADMIN, MINTER ROLES
  /**
  * @dev CONTRACT_ROLE reveals URI for contract
  *
  *  - Emits a {Reveal} event.
  */
  function reveal() override external whenNotPaused() onlyContractAdmin {
    require(!useDynamicRules, "Failed using dynamic rules, use revealDynamic");
    revealed = true;

    emit Reveal(msg.sender);
  }
  /**
  * @dev CONTRACT_ROLE reveals URI for dynamic contract
  *
  *  - Emits a {Reveal} event.
  */
  function revealDynamic(string memory _newBaseURI) external whenNotPaused() onlyContractAdmin {
    _recentStateSet = 0;
    _stateURI[_recentStateSet] = _newBaseURI;
    revealed = true;

    emit Reveal(msg.sender);
  }
  /**
  * @dev Set use of dynamic rules in contracty 
  *  Owner of contract can turn off / on the use of dynamic rules only
  *  
  *  - Emits a {RuleUpdate} event.
  */
  function useUseDynamicRules(bool _state) external onlyOwner {
    useDynamicRules = _state;
    uint state = useMintRules ? uint(1) : uint(0);

    emit RuleUpdate(msg.sender, string.concat("Setting dynamic rules: ",state.toString()));
  }
 /**
  * @dev Update all dynamic states for contract.
  *   It is only updating the tokens that have been already minted. Any new token minted 
  *   after this call wont have this state.
  * 
  *  - Emits a {StateUpdate} event.
  */
  function updateAllDynamicStates(uint256 _nstate, string memory _newBaseURI) 
    external 
    whenNotPaused()
    onlyContractAdmin 
  {
    require(revealed, "Cant update - contract is not revealed");
    require(_recentStateSet == _nstate - 1, "Dynamic state is not being updates, wrong state provided.");

    uint256 totalSupply = totalSupply();
    for(uint256 i = 1; i <= totalSupply;) {
      _tokenState[i] = _nstate;
      unchecked { i++; }
    }
    _recentStateSet = _nstate;
    _stateURI[_nstate] = _newBaseURI;

    emit StateUpdate(msg.sender, _nstate, string.concat("Updating dynamic state for all tokens: ", totalSupply.toString()));
  }
  /**
  * @dev Updates URI for a dynamic state `_updateState`.
  *   - Sets new URI`_newBaseURI` in state map.
  *   - If latest state, updates recent
  *
  *  - Emits a {StateUpdate} event.
  */
  function updateDynamicStateURI(string memory _newBaseURI, uint256 _updateState) 
    external 
    whenNotPaused() 
    onlyContractAdmin 
  {
    require(revealed, "Cant update - contract is not revealed");
   
    _stateURI[_updateState] = _newBaseURI;
    if(_recentStateSet < _updateState) {
      _recentStateSet = _updateState;
    }

    emit StateUpdate(msg.sender, _updateState, "Updating dynamic state URI ");
  }
  /**
  * @dev Updates dynamic state `_updateState` for `tokenId` in contract.
  *
  *  - Emits a {StateUpdate} event.
  */
  function updateTokenDynamicState(uint256 _tokenId, uint256 _updateState) 
    external  
    whenNotPaused()
    onlyContractAdmin 
  {
    require(revealed, "Cant update - contract is not revealed");
    require(_updateState <= _recentStateSet, "State provided not set");
    require(_exists(_tokenId), "Failed, updating state for nonexistent token");

    _tokenState[_tokenId] = _updateState;

    emit StateUpdate(msg.sender, _updateState, string.concat("Updating dynamic state for token: ",_tokenId.toString()));
  }
}