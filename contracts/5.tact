import "@stdlib/deploy";

/*
  TASK 5 - NFT random swap 
  The smart contract contains a bunch of different NFTs.
  A user brings his NFT (sends it to the smart contract), with 2.1 TON (2 for admin's profit, 0.1 for gas) in attachment (as fee for swap).
  The smart contract randomly chooses some NFT from the available NFTs (including the newly incoming one) and gives it to the user in exchange for the brought NFT (but occasionally just returns user's NFT in some cases).
  Admin can deposit NFTs without swap logic. Any NFT received from the admin is considered deposited. Admin can't swap.
  Admin can withdraw all NFTs at once, and also all TONs collected from users as fees.

  In details, the smart contract (later: SC) should have this logic:
  Messages
  * AdminWithdrawalProfit 
   - SC should check that sender is the admin / otherwise throw "Insufficient privelegies"
   - SC should send all collected fees to admin except 0.1 TON (use AdminFetchProfit message as body)
     In other words: after each such operation, the contract's balance should be equal to 0.1 TON (which are reserved for storage) and the rest should be sent to the admin
  * AdminWithdrawalAllNFTs
   - SC should check that incoming tx TON value is enough for NFT withdrawal. Specifically, at least: (1 + totalNftsHeld * 0.08) TONs. Otherwise throw "Insufficent funds"
   - SC should check that sender is the admin, throw "Invalid sender" otherwise
   - If all checks pass, SC should send NFTs one by one to the admin 
   - SC should be able to withdraw all NFTs by a single message from admin
  * OwnershipAssigned 
   - if prevOwner is the owner's (admin) address, then add NFT to the collection
   - if value of TON attached is less then 2.1 TON then stop execution and return NFT back,
     but only in case that TON attached is enough to process refund without losing TONs on the SC's balance
   - randomly select NFT to send from all the NFTs that smart contract has
   - send the selected NFT to the sender with all remaining balance (except for admin profit = fees collected from this and other swaps)
     In other words: the contract's balance should increase by exactly 2 TON, some incoming TONs will be consumed for gas and the remainings of the incoming TONs should be refunded to the sender
  
  Getters
  - profit - returns how much collected fees is available to withdraw for the admin (all fees minus 0.1 TON)
  - nfts - returns dict of held NFTs with NFT indexes (sequential numbers from 0, 1, 2 ... and up to 'totalNftsHeld-1') as keys and NFT address as values 
     the order of NFTs in this dictionary doesn't matter
*/

message AdminWithdrawalProfit {
    queryId: Int as uint64;
}

message AdminWithdrawalAllNFTs {
    queryId: Int as uint64;
}

message AdminFetchProfit {
    queryId: Int as uint64;
}

message(0x05138d91) OwnershipAssigned {
    queryId: Int as uint64;
    prevOwner: Address;
    forwardPayload: Slice as remaining;
}

message(0x5fcc3d14) Transfer {
    queryId: Int as uint64;
    newOwner: Address;
    responseDestination: Address;
    customPayload: Cell?;
    forwardAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

contract Task5 with Deployable {
    seed: Int as uint128 = 0;
    owner: Address;
    assets: map<Int as uint16, Address>;
    held: Int as uint16 = 0;
    
    init(seed: Int, owner: Address) {
        self.assets = emptyMap();
        self.owner = owner;
        self.seed = seed;
    }
    
    receive(msg: OwnershipAssigned) {
        if (msg.prevOwner == self.owner) {
            self.assets.set(self.held, sender());
            self.held = self.held + 1;
            return;
        }
        
        let nft: Address = sender();
        if (context().value < ton("2.1")) {
            // nativeReserve(context().value, 1);
            send(SendParameters{
                to: nft,
                value: 0,
                mode: SendRemainingValue,
                body: Transfer{queryId:msg.queryId, newOwner:msg.prevOwner, responseDestination:msg.prevOwner,
                    customPayload:null, forwardAmount:0, forwardPayload:emptySlice()}.toCell()
            });
            return;
        }
        
        let rand_idx: Int = randomInt() % (self.held + 1);
        if (rand_idx != self.held) {
            nft = self.assets.get(rand_idx)!!;
            self.assets.set(rand_idx, sender());
        }
        
        // nativeReserve(context().value - ton("2.0"), 1);
        send(SendParameters{
            to: nft,
            value: context().value - ton("2.0"),
            mode: 0,
            body: Transfer{queryId:msg.queryId, newOwner:msg.prevOwner, responseDestination:msg.prevOwner,
                customPayload:null, forwardAmount:0, forwardPayload:emptySlice()}.toCell()
        });
    }
    
    receive(msg: AdminWithdrawalProfit) {
        require(sender() == self.owner, "Insufficient privelegies");
        
        nativeReserve(ton("0.1"), 0);
        send(SendParameters{
            to: self.owner,
            value: 0,
            mode: SendRemainingBalance,
            body: AdminFetchProfit{queryId:msg.queryId}.toCell()
        });
    }
    
    receive(msg: AdminWithdrawalAllNFTs) {
        if (sender() != myAddress()) {
            require(sender() == self.owner, "Invalid sender");
            require(context().value >= ton("1") + self.held * ton("0.08"), "Insufficent funds");
        }
        acceptMessage();
        
        let mv: Cell = Transfer{queryId:msg.queryId, newOwner:self.owner, responseDestination:self.owner, customPayload:null, forwardAmount:0, forwardPayload:emptySlice()}.toCell();
        repeat(min(100, self.held)) {
            self.held = self.held - 1;
            send(SendParameters{
                to: self.assets.get(self.held)!!, value: ton("0.02"), mode: 0, body: mv
            });
        }
        if (self.held > 0) {
            send(SendParameters{
                to: myAddress(), value: 0, mode: SendRemainingBalance, body: AdminWithdrawalAllNFTs{queryId:msg.queryId}.toCell()
            });
        } else {
            self.assets = emptyMap();
        }
    }
    
    get fun profit(): Int {
        return myBalance() - ton("0.1");
    }
    
    get fun nfts(): map<Int as uint16, Address> {
        self.assets.set(self.held, null);
        return self.assets;
    }
}
