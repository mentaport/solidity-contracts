# Mentaport Solidity Contracts

This repository contains Mentaport's solidity smart contracts. The contracts are separated into the
following folders:

`/interfaces`: This folder contain interfaces which are useful for integrating with Mentaport's 
contracts.

`/main`: This folder contains the 3 core contracts that power Mentaport's location-aware features.
`MentaportERC721` is our bare metal contracts that contains internal functions for minting NFTs.
`MentaportMint` extends the `MentaportERC721` contract, adds some guards and access control checks to
external functions that can be called for minting. `MentaportVerify` is our access control contract
that manages access to all our contracts and derived 
[examples](https://github.com/mentaport/mentaport-nft-examples). It is also responsible for signatures 
and proofs verification. 

`/supplements`: This folder contain useful contracts that extend the core ideas of the core contracts

### Installation 
```shell
npm install @mentaport/solidity-contracts
```

### Setup
Our contracts were built using the truffle framework. You'd need to setup truffle on your machine to set
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

