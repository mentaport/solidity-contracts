# Mentaport Solidity Contracts

This repository contains Mentaport's solidity smart contracts. The contracts are separated into the
following folders:

`/interfaces`: This folder contain interfaces which are useful for integrating with Mentaport's 
contracts.

`/main`: This folder contains the 3 core contracts that power Mentaport's location-aware features.
- `MentaportERC721`: Our bare metal contract that contains internal functions for minting NFTs.
- `MentaportMint`: Extends the `MentaportERC721` contract and adds the ability for minting with location rules.
    - We have designed our main mint contract to have dynamic tokenURI, meaning that you will pass a unique tokenURI at minting.
    - If you want more traditional minting, check the supplement minting contract.
- `MentaportVerify`: Our access control contract that manages access to all our contracts.
  It is also responsible for signatures and proofs verification.
- `/supplements`: This folder contain useful contracts that extend the core ideas of the main contracts for simpler tokenURI management. 


[Examples of live Contracts](https://github.com/mentaport/mentaport-nft-examples)

---
### Installation 
You can add our contracts to your project by simply installing the library:
```shell
npm install @mentaport/solidity-contracts
```
---
### Run Tests
Our contracts were built using the truffle framework. If you want to run our tests, you will need to setup truffle on your machine to set
up the contracts on your machine. Check out how to setup truffle 
[here](https://trufflesuite.com/docs/truffle/how-to/install/). Follow these stops to setup and
test the contracts:

cd into the truffle directory:
```shell
cd truffle
```

install contract dependencies
```shell
npm install
```

test the contracts
```shell
truffle test
```

