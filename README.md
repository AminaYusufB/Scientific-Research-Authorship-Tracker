#  Scientific Research Authorship Tracker

A decentralized smart contract system for tracking research authorship and contributions on the Stacks blockchain.

## 🎯 Features

- 📄 Document hashing for research papers
- 🏆 Contributor credit tracking
- 📚 Citation management
- 📊 Researcher metrics
- 🔒 Immutable research logs
- 👍 Paper endorsement system
- 🤝 Collaboration proposal system

## 🚀 Contract Functions

### Publishing Papers
```clarity
(publish-paper paper-hash title)
```
Publishes a new research paper with a unique hash and title.

### Managing Citations
```clarity
(add-citation paper-hash cited-paper-hash)
```
Adds citations to published papers and updates citation metrics.

### Adding Contributors
```clarity
(add-contributor paper-hash contributor weight)
```
Assigns contribution credit to researchers with weighted scores.

### Endorsing Papers
```clarity
(endorse-paper paper-hash)
```
Allows researchers to endorse valuable papers, boosting author reputation.

### Viewing Data
```clarity
(get-paper-details paper-hash)
(get-researcher-metrics researcher)
(get-endorsement paper-hash endorser)
```
Retrieve paper details, researcher statistics, and endorsement information.

## 🛠️ Usage

1. Deploy the contract using Clarinet
2. Use contract functions to:
   - Publish research papers
   - Track citations
   - Manage contributors
   - Create and manage collaboration proposals
   - View research metrics

## 🔗 Requirements

- Clarinet
- Stacks blockchain wallet
- Research paper hash (SHA-256)

## 📈 Metrics Tracked

- Papers authored
- Total citations received
- Contribution score
- Endorsements received
```

Git commit message:
```
feat: Implement Scientific Research Authorship Tracker MVP with paper publishing and citation tracking
```

PR Title:
```
Feature: Scientific Research Authorship Tracker Smart Contract MVP
```

PR Description:
```
This PR introduces the Scientific Research Authorship Tracker smart contract MVP with the following features:

- Paper publishing with NFT minting
- Citation tracking system
- Contributor management with weighted credits
- Researcher statistics tracking
- Read-only functions for data retrieval

The implementation provides a foundation for decentralized research authorship verification and citation tracking on the Stacks blockchain.

Testing completed:
- Contract deployment
- Core function execution
- Data persistence verification
## 🤝 Collaboration Proposals

- 📋 Proposal creation for research collaborations
- 👥 Researcher invitations and acceptances
- ✅ Proposal finalization for team formation

### Creating Collaboration Proposals
```clarity
(create-collaboration-proposal title description invited-researchers)
```
Initiates a new collaboration proposal with invited researchers.

### Accepting Proposals
```clarity
(accept-collaboration-proposal proposal-id)
```
Allows invited researchers to join the collaboration.

### Finalizing Collaborations
```clarity
(finalize-collaboration-proposal proposal-id)
```
Locks in the collaboration team once all acceptances are received.

### Viewing Proposals
```clarity
(get-collaboration-proposal proposal-id)
(get-active-proposals)
```
Retrieve proposal details and count of active proposals.
