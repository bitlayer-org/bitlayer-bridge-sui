import { SuiClient } from '@mysten/sui/dist/cjs/client'
import { Transaction } from '@mysten/sui/transactions'
import { config } from './config'
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519'
import { ethers } from 'ethers'
import { bcs, fromHex } from '@mysten/bcs'

export const createCommittee = async (
  suiClient: SuiClient,
  tx: Transaction
) => {
  const keypair = Ed25519Keypair.fromSecretKey(config.submitter() || '')
  const pubkeys = []
  const stakeds = []
  config.committees.map((c) => {
    const wallet = new ethers.Wallet(c.privateKey())
    // wallet.address
    // const sign = new SigningKey(c.privateKey())

    pubkeys.push(fromHex(wallet.address))
    stakeds.push(c.staked)
  })

  tx.moveCall({
    target: `${config.package()}::bridge::create_bridge_committee_by_vec`,
    arguments: [
      tx.object(config.bridge()),
      tx.object(config.admin_cap()),
      tx.pure(bcs.vector(bcs.vector(bcs.u8())).serialize(pubkeys)),
      tx.pure.vector('u64', stakeds),
      tx.pure.u64(10000),
    ],
  })

  // const result = await suiClient.devInspectTransactionBlock({
  //   transactionBlock: tx,
  //   sender: keypair.getPublicKey().toSuiAddress(),
  // })
  const result = await suiClient.signAndExecuteTransaction({
    transaction: tx,
    signer: keypair,
  })

  console.log('createCommittee: ', result)
}
