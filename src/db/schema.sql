DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


CREATE TABLE transfers(
  hash            text        PRIMARY KEY,
  source_hash     text        NOT NULL, -- hash (can be a transaction_hookins(hash), a lightning_hookins(hash) or a set of spent_coins)
  output_hash     text        NOT NULL,
  acknowledgement text        NOT NULL,
  created         timestamptz     NULL DEFAULT NOW() -- prunable
);

CREATE TABLE spent_coins(
   owner                      text     PRIMARY KEY,
   transfer_hash              text     NOT NULL REFERENCES transfers(hash),
   magnitude                  smallint NOT NULL,
   existence_proof            text     NOT NULL, -- unblinded signature
   spend_authorization        text     NOT NULL -- signature of owner signs the transfer_hash
);
CREATE INDEX spent_coins_transfer_hash_idx on spent_coins(transfer_hash);


CREATE TABLE claimable_coins(
  id                        bigserial         PRIMARY KEY,
  transfer_hash             text                  NULL REFERENCES transfers(hash), -- DEBUG_ONLY
  claimant                  text              NOT NULL, -- can be dupes, but highly discouraged
  magnitude                 smallint          NOT NULL           
);

CREATE INDEX claimable_coins_transfer_hash_idx ON claimable_coins(transfer_hash);
CREATE INDEX claimable_coins_claimant_idx ON claimable_coins(claimant, magnitude);


CREATE TABLE claims(
  claimable_coins_id        bigint            PRIMARY KEY REFERENCES claimable_coins(id),
  -- the claim request is below
  request_hash                      text              NOT NULL UNIQUE,
  request_blind_nonce               text              NOT NULL,
  request_blinded_owner             text              NOT NULL,
  request_authorization             text              NOT NULL,
  -- the response we gave --
  response_blinded_existence_proof  text              NOT NULL,
  response_acknowledgement          text              NOT NULL,
  --- debug ---
  created                           timestamptz           NULL DEFAULT NOW() -- prunable
);


CREATE TABLE transaction_hookins(
  hash                        text        PRIMARY KEY,
  transfer_hash               text        NOT NULL REFERENCES transfers(hash),
  spend_authorization         text            NULL,
  -- everything below is prunable data (after it's been spent...)
  txid                        text            NULL,
  vout                        int             NULL,
  amount                      bigint          NULL,
  credit_to                   text            NULL,
  derive_index                bigint          NULL, -- to store a uint32
  tweak                       text            NULL, -- debug info
  deposit_address             text            NULL -- debug info
);
CREATE UNIQUE INDEX transaction_hookins_transfer_hash_idx ON transaction_hookins(transfer_hash);

-- SENDING means it's in progress (or locked up)
-- SENT means it's totally done and pushed onto the network
CREATE TYPE TRANSACTION_SEND_STATUS_ENUM AS ENUM('SENDING', 'SENT', 'FAILED');

CREATE TABLE bitcoin_transactions(
  txid                   text                         PRIMARY KEY,
  hex                    text                         NOT NULL,
  fee                    bigint                       NOT NULL,
  status                 TRANSACTION_SEND_STATUS_ENUM NOT NULL,
  created                timestamptz                  NOT NULL DEFAULT NOW()
);

-- interestingly once a hookout is safely sent, it's *completely* prunable (e.g. we can just delete it!)
CREATE TABLE transaction_hookouts(
  hash                           text     PRIMARY KEY,
  transfer_hash                  text        NULL REFERENCES transfers(hash),  -- DEBUG_ONLY
  amount                         bigint   NOT NULL,
  bitcoin_address                text     NOT NULL,
  nonce                          text     NOT NULL,
  immediate                      boolean  NOT NULL,
  txid                           text         NULL REFERENCES bitcoin_transactions(txid)
);

CREATE INDEX transaction_hookouts_transfer_hash_idx ON transaction_hookouts(transfer_hash);
CREATE INDEX transaction_hookouts_transfer_txid_idx ON transaction_hookouts(txid);




-- CREATE OR REPLACE FUNCTION jsonize_transaction(t transactions) RETURNS jsonb
--     AS $$
--       SELECT jsonb_build_object(
--       'hash', t.hash,
--       'sourceHash', t.source_hash,
--       'sourceInputs', (
--         SELECT jsonb_agg(jsonb_build_object(
--           'owner', transaction_inputs.owner,
--           'coinMagnitude', transaction_inputs.coin_magnitude,
--           'existenceProof', transaction_inputs.existence_proof,
--           'spendProof', transaction_inputs.spend_proof 
--         ))
--         FROM transaction_inputs
--       WHERE transaction_inputs.transfer_hash = t.hash
--      ),
--       'claimableOutputs', (
--             SELECT jsonb_agg(jsonb_build_object(
--                   'claimant', claimable_outputs.claimant,
--                   'coinMagnitude', claimable_outputs.coin_magnitude
--             ))
--             FROM claimable_outputs
--             WHERE claimable_outputs.transfer_hash = t.hash
--            ),
--       'defundingOutput', (
--           SELECT jsonb_build_object('priority', defunding_outputs.priority)
--           FROM defunding_outputs
--           WHERE defunding_outputs.transfer_hash = t.hash
--        ),
--        'acknowledgement', t.acknowledgement
--     )
--     $$
--     LANGUAGE SQL
--     IMMUTABLE
--     RETURNS NULL ON NULL INPUT;
