# Vector Databases (RAG Backends)

Vector databases store embedded representations of documents and are often connected to LLM pipelines for Retrieval-Augmented Generation (RAG). They can inadvertently expose sensitive document content and should be treated as data stores requiring the **same protections as the underlying data**.

> **Ref:** [NIST SP 800-53 SC-28](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final) (Protection of Information at Rest)

---

## Supported Vector Databases

| Tool | Default Port | Notes |
|---|---|---|
| **Qdrant** | `6333` (REST), `6334` (gRPC) | No auth by default in local mode |
| **Chroma / ChromaDB** | `8000` | Embedded or server mode; no auth in embedded mode |
| **Weaviate** | `8080` | GraphQL API; no auth by default |
| **Milvus** | `19530` | Production-grade; auth optional but not enforced by default |
| **pgvector** | `5432` (PostgreSQL) | Inherits Postgres auth — ensure Postgres is secured |
| **Redis Stack** | `6379` | Redis with vector search; requires explicit auth config |

---

## Security Requirements

1. **Enable authentication** on all vector database instances — most ship with auth disabled
2. **Bind to localhost** (`127.0.0.1`) unless a specific network use case requires otherwise
3. **Firewall the port** — block external access via host firewall and network segmentation
4. **Encrypt data at rest** — vector embeddings derived from sensitive documents must be encrypted at rest per NIST SP 800-53 SC-28
5. **Classify before indexing** — do not index CUI, PII, PHI, or classified data into a vector database without a formal security review and appropriate controls in place
6. **Audit access** — enable query logging and integrate with your centralized audit log
7. **Review RAG pipeline inputs** — documents fed into a RAG pipeline may contain injection payloads; treat all document content as untrusted input

---

## Data Classification and Vector Databases

| Data Type | May Be Indexed? |
|---|---|
| Public / unrestricted internal data | ✅ With IT approval and standard controls |
| PII (names, SSNs, addresses) | 🔴 **No** — without DPA, security review, and encryption at rest |
| PHI (patient records, HIPAA data) | 🔴 **No** — without BAA, security review, and encryption at rest |
| CUI (Controlled Unclassified Information) | 🔴 **No** — without CMMC/NIST 800-171 controls in place |
| Source code (proprietary) | ⚠️ Only with IT approval, local-only deployment, no external APIs |
| Credentials / secrets | 🔴 **Never** |

---

← [Back to Wiki Home](Home)
