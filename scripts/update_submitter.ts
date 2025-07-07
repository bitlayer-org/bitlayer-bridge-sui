import { SuiClient } from '@mysten/sui/dist/cjs/client'
import { Transaction } from '@mysten/sui/transactions'
import { config } from './config'
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519'

export const updateSubmitter = async (
  suiClient: SuiClient,
  tx: Transaction
) => {
  const keypair = Ed25519Keypair.fromSecretKey(Buffer.from(config.admin(), 'hex') || '')
  tx.moveCall({
    target: `${config.package()}::bridge::update_submitter`,
    arguments: [
      tx.object(config.bridge()),
      tx.object(config.admin_cap()),
      tx.pure.address(config.submitter()),
      tx.pure.bool(true),
    ],
  })
  // const result = await suiClient.signAndExecuteTransaction({
  //   transactionBlock: tx,
  //   sender: keypair.getPublicKey().toSuiAddress(),
  // })
  const result = await suiClient.signAndExecuteTransaction({
    transaction: tx,
    signer: keypair,
  })

  console.log('updateSubmitter: ', result)
}
