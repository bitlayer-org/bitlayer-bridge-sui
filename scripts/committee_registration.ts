import { SuiClient } from '@mysten/sui/dist/cjs/client'
import { Transaction } from '@mysten/sui/transactions'
import { config } from './config'
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519'
import { Wallet } from 'ethers'
import { bcs, fromHex } from '@mysten/bcs'

export const committeeRegistration = async (
  suiClient: SuiClient,
  tx: Transaction
) => {
  const keypair = Ed25519Keypair.fromSecretKey(fromHex(config.admin()) || '')
  const pubkeys = []
  config.committees.map((c) => {
    const wallet = new Wallet(c.privateKey())
    pubkeys.push(fromHex(wallet.address))
    console.log('wallet: ', wallet.address)
  })
  // process.exit(0)

  tx.moveCall({
    target: `${config.package()}::bridge::committee_registration`,
    arguments: [
      tx.object(config.bridge()),
      tx.object(config.admin_cap()),
      tx.pure(bcs.vector(bcs.vector(bcs.u8())).serialize(pubkeys)),
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

  console.log('committeeRegistration: ', result)
}
