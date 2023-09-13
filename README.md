# Noun Vesting

A helper contract for Nouns DAO to transfer Nouns to partners and community members, with the following requirements:

Nouns sender (Nouns DAO) can:

- Set a vesting end timestamp, afterwhich the recipient can claim their Nouns.
- Set a price per token the recipient needs to pay to claim their Nouns.
- Clawback Nouns until the vesting end timestamp.

Recipient can:

- Delegate the Nouns held in this contract to any Ethereum address they like, as soon as they are sent to this contract.
- Buy the tokens held in this contract, at the price per token set by the sender, once vesting is over.
- Receive an NFT that represents their role in the vesting contract, allowing them to transfer it among their wallets, or to anyone else.
