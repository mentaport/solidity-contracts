# <h1 align="center"> Mentaport Contracts </h1> <h6 align="center"> [![Github Actions][gha-badge]][gha] [![Foundry][foundry-badge]][foundry] </h6>

[gha]: https://github.com/mentaport/mentaport-core-contracts/actions
[gha-badge]: https://github.com/mentaport/mentaport-core-contracts/actions/workflows/ci.yml/badge.svg
[foundry]: https://getfoundry.sh
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

This repository contains the core smart contracts of the Mentaport Certificate Platform. In-depth documentation is available at
[docs.mentaport.com](https://docs.mentaport.com/).


## Getting Started
Before you begin, make sure you have the following tools and dependencies installed:

* [Node.js](https://nodejs.org/en) (>=16.x)
* [npm](https://www.npmjs.com/) (Node Package Manager)
* [Solc](https://docs.soliditylang.org/en/latest/installing-solidity.html#npm-node-js) and [Solc-select](https://github.com/crytic/solc-select)
* [Foundry](https://github.com/foundry-rs/foundry) (Install globally with npm install -g foundry)

1. Install forge dependencies
```shell
forge install
```
2. Install yarn/npm dependencies
```shell
yarn/npm install
```
3. Build contracts
```shell
make build
```
4. Run tests on contracts
```shell
make test
```
5. Run trace on contracts
```shell
make trace
```
6. Install [slither](https://github.com/crytic/slither#how-to-install)
```shell
pip3 install slither-analyzer
```
7. Run static analysis on contracts
```shell
yarn run slither:analyze
```

