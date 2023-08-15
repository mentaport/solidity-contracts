const truffleAssert = require("truffle-assertions");
const MentaportDynamicContract = artifacts.require('MentaportDynamic');

contract('MentaportDynamic - dynamic states', function(accounts) {
    let instance = null;
    let contractAddress;
    
    const owner = accounts[0];
    const userAdmin = accounts[1];
    const userMinter = accounts[2];
    const userB = accounts[3];
    const originURI = "https://revealed_path/";
    const firstDynamicState = "https://first_dynamic_state/";

    before(async () => {
        instance =  await MentaportDynamicContract.deployed();
        contractAddress = instance.address;

        await instance.unpause();
        // mint some NFT to check dynamic states
        await instance.mintForAddress(2, userAdmin, {from:userMinter});
        await instance.mintForAddress(2, owner, {from:userMinter});
    });

    it('should fail to update dynamic state for all tokens when contract is not revealed', async() => {
        const newState = 1;
        await truffleAssert.fails(
          instance.updateAllDynamicStates(newState, firstDynamicState),
          truffleAssert.ErrorType.REVERT,
          "Cant update - contract is not revealed"
        );
    });

    it('should fail to reveal in dynamic contract if rules are enabled', async() => {
        await truffleAssert.fails(
          instance.reveal(),
          truffleAssert.ErrorType.REVERT,
          "Failed using dynamic rules, use revealDynamic"
        );
    });

    it('should reveal in dynamic contract if rules are enabled', async() => {
        await instance.revealDynamic(originURI);
        expect(await instance.revealed()).to.be.true;
    });

    it('should fail to update dynamic state if state is wrong', async() => {
        const newState = 3;
        await truffleAssert.fails(
          instance.updateAllDynamicStates(newState, firstDynamicState),
          truffleAssert.ErrorType.REVERT,
          "Dynamic state is not being updates, wrong state provided"
        );
    });

    
    it('should fail to update dynamic state if role is wrong', async() => {
        const newState = 1;
        await truffleAssert.fails(
          instance.updateAllDynamicStates(newState, firstDynamicState, {from:userMinter}),
          truffleAssert.ErrorType.REVERT,
          "Caller is not contract admin"
        );
    });

    it('should update dynamic state for all tokens', async() => {
        const newState = 1;
        const tx = await instance.updateAllDynamicStates(newState, firstDynamicState);

        truffleAssert.eventEmitted(tx, 'StateUpdate', event => {
            return (
              event.admin === owner &&
              event.state.toNumber() === newState
            );
        });

        let tokenId = 1;
        let tokenURI = await instance.tokenURI(tokenId);
        expect(tokenURI).to.equal(firstDynamicState+`${tokenId}.json`);
        tokenId = 2;
        tokenURI = await instance.tokenURI(tokenId);
        expect(tokenURI).to.equal(firstDynamicState+`${tokenId}.json`);
    });

    it('should fail to update dynamic state by +1 to particular tokenID if state not set', async() => {

        let tokenId = 2;
        let newState = await instance.getTokenState(tokenId);
        newState = newState.words[0] + 1;
        await truffleAssert.fails(
          instance.updateTokenDynamicState(tokenId, newState),
          truffleAssert.ErrorType.REVERT,
          "State provided not set"
        );
    });

    it("should update the dynamic state by +1 to particular tokenID and set URI", async() => {
        const tokenId = 2;
        const newPath = "https://new_path_one/";
    
        let newState = await instance.getTokenState(tokenId);
        newState = newState.words[0] + 1;
        await instance.updateDynamicStateURI(newPath, newState);
        await instance.updateTokenDynamicState(tokenId, newState);

        const tokenURI = await instance.tokenURI(tokenId);
        expect(tokenURI).to.equal(newPath+`${tokenId}.json`);
        // check that other tokens still old uri
        const tokenId_other = 1;
        const tokenURI_other = await instance.tokenURI(tokenId_other);
        expect(tokenURI_other).to.equal(firstDynamicState+`${tokenId_other}.json`);
    });

    it('should update tokenId state to previous state', async() => {
        const tokenId = 2;
        let currentState = await instance.getTokenState(tokenId);
        currentState = currentState.words[0];
        let prevState = currentState - 1

        await instance.updateTokenDynamicState(tokenId, prevState);
        const newTokenURI = await instance.tokenURI(tokenId);

        const stateURI = await instance.getURIforState(prevState);
        const tokenURI = await instance.tokenURI(tokenId);

        expect(newTokenURI).to.equal(tokenURI);
        expect(tokenURI).to.equal(stateURI+`${tokenId}.json`);
    });

    it('should fail to update dynamic state to previous state if wrong previous state', async() => {
        const tokenId = 2;
        let currentState = await instance.getTokenState(tokenId);
        currentState = currentState.words[0];
        let prevState = currentState - 10
       // TODO:
        // await truffleAssert.fails(
        //   instance.updateTokenDynamicState(tokenId, prevState),
        //   'Error: ',
        //   "value out-of-bounds"
        // );
    });

    it('should get the new minted token URI after updating it', async() => {
        let newState = await instance.recentStateSet();
        newState = newState.words[0] + 1;
        const newPath = "https://new_path_update/";
        let totalSupply = (await instance.totalSupply()).toNumber()
        await instance.updateAllDynamicStates(newState, newPath);
      
        // new  mint - has to have init uri
        await instance.mintForAddress(1, userB, {from:userMinter});
        
        let newTotalSupply = (await instance.totalSupply()).toNumber()
        let tokenURIUpdate = await instance.tokenURI(totalSupply);
        let tokenURINew = await instance.tokenURI(newTotalSupply);
        expect(tokenURIUpdate).to.equal(newPath+`${totalSupply}.json`);
        expect(tokenURINew).to.equal(originURI+`${newTotalSupply}.json`);
    });

});
