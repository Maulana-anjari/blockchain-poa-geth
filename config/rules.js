// File: config/rules.js
// This file defines the signing rules for Clef. It allows for the automation of
// specific signing tasks, like sealing PoA blocks, while maintaining security by
// rejecting other types of requests by default.

/**
 * This function is called once when the Clef signer starts. It can be left empty
 * or used for logging startup information.
 * @param {object} info - Information about the signer startup.
 */
function OnSignerStartup(info) {
  // For debugging, you can uncomment the following line:
  // console.log("Clef Signer Started: ", JSON.stringify(info));
}

/**
 * This function allows a client (like Geth) to list the accounts managed by this Clef instance.
 * Returning "Approve" is essential for Geth to identify which account to use when the
 * --signer flag is active.
 * @returns {string} - "Approve" to allow account listing.
 */
function ApproveListing() {
  return "Approve";
}

/**
 * This function is called by Clef for every data signing request that requires approval.
 * It uses the 'CLEF_MODE' environment variable to switch between a secure default
 * and a permissive benchmark mode.
 * * @param {object} r - The request object from Clef, containing details about the signing request.
 * @returns {string} "Approve" or "Reject".
 */
function ApproveSignData(r) {
  // [Secure Mode]
  // Uncomment this for use secure mode
  // First, check if the content type matches a Clique header.
  // if (r.content_type == "application/x-clique-header") {
  //   // Let Clef perform its internal verification on the message payload.
  //   for (var i = 0; i < r.messages.length; i++) {
  //     var msg = r.messages[i];
  //     // If Clef confirms the message is a valid Clique header...
  //     if (msg.name == "Clique header" && msg.type == "clique") {
  //       // ...then automatically approve the signing request.
  //       console.log("Approved clique header signing for block ", msg.value);
  //       return "Approve";
  //     }
  //   }
  // }

  // // By default, reject all other types of data signing requests.
  // // This is a critical security measure to prevent the signer from signing arbitrary data.
  // console.log("Rejected generic data signing request: ", JSON.stringify(r));
  // return "Reject";

  // [Benchmarking Mode]
  // Comment this for secure mode
  console.log(">>> SIGNING REQUEST RECEIVED: " + JSON.stringify(r));
  return "Approve";
}

/**
 * This function handles transaction signing requests.
 * In a pure PoA setup, the signer's primary role is to seal blocks, not to send transactions.
 * @param {object} r - The transaction request object.
 * @returns {string} - "Reject" to block all outgoing transactions from this account.
 */
function ApproveTx(r) {
  console.log("Received Tx request: ", JSON.stringify(r));
  // For maximum security, we will reject all outgoing transaction requests from this account.
  // If transactions need to be sent, they should originate from a different, non-signer account.
  return "Reject";
}
