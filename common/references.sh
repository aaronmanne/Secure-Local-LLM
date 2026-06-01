#!/usr/bin/env bash
# =============================================================================
# common/references.sh
# U.S. Federal regulatory citations and guidance references relevant to
# securing local LLM software.  Sourced by all bash scripts to print a
# consistent references footer.
# =============================================================================

# ─── CITATION DATABASE ────────────────────────────────────────────────────────
# Each entry: "SHORT_ID|TITLE|URL"
FEDERAL_REFERENCES=(

  # ── NIST AI Framework & Guidelines ──────────────────────────────────────────
  "NIST AI 100-1|NIST AI Risk Management Framework (AI RMF 1.0)|https://doi.org/10.6028/NIST.AI.100-1"
  "NIST AI 100-2|NIST Adversarial Machine Learning: A Taxonomy and Terminology|https://doi.org/10.6028/NIST.AI.100-2"
  "NIST AI 600-1|NIST Artificial Intelligence Risk Management Framework for Generative AI|https://doi.org/10.6028/NIST.AI.600-1"
  "NIST SP 800-53r5|NIST SP 800-53 Rev 5: Security & Privacy Controls for Information Systems|https://doi.org/10.6028/NIST.SP.800-53r5"
  "NIST SP 800-171r3|NIST SP 800-171 Rev 3: Protecting CUI in Nonfederal Systems|https://doi.org/10.6028/NIST.SP.800-171r3"
  "NIST SP 800-218|NIST SP 800-218: Secure Software Development Framework (SSDF)|https://doi.org/10.6028/NIST.SP.800-218"

  # ── Executive Orders ────────────────────────────────────────────────────────
  "EO 14110|Executive Order on Safe, Secure, and Trustworthy AI (Oct 30, 2023)|https://www.whitehouse.gov/briefing-room/presidential-actions/2023/10/30/executive-order-on-the-safe-secure-and-trustworthy-development-and-use-of-artificial-intelligence/"
  "EO 14179|Executive Order: Removing Barriers to American Leadership in AI (Jan 23, 2025)|https://www.whitehouse.gov/presidential-actions/2025/01/removing-barriers-to-american-leadership-in-artificial-intelligence/"

  # ── OMB Policy Memoranda ────────────────────────────────────────────────────
  "OMB M-24-10|OMB M-24-10: Advancing Governance, Innovation, and Risk Management for Agency AI Use|https://www.whitehouse.gov/wp-content/uploads/2024/03/M-24-10-Advancing-Governance-Innovation-and-Risk-Management.pdf"
  "OMB M-24-18|OMB M-24-18: Improving the Security of Federal Systems and Related AI Guidance|https://www.whitehouse.gov/wp-content/uploads/2024/07/M-24-18-Securing-the-US-Government-Use-of-AI.pdf"

  # ── CISA ───────────────────────────────────────────────────────────────────
  "CISA AI-ROADMAP|CISA Roadmap for Artificial Intelligence 2023–2024|https://www.cisa.gov/sites/default/files/2023-11/2023-2024-CISA-Roadmap-for-AI.pdf"
  "CISA-JCSA-2024|CISA/NSA/FBI Joint CSA: Cybersecurity Risks from Foreign-Origin AI Tools|https://www.cisa.gov/news-events/alerts"
  "CISA-AI-THREATS|CISA Guidance on Defending AI Systems Against Adversarial Attacks|https://www.cisa.gov/ai"
  "CISA-LLMSEC|CISA/UK NCSC: Guidelines for Secure AI System Development|https://www.cisa.gov/sites/default/files/2023-11/guidelines_for_secure_ai_system_development_508c.pdf"

  # ── NSA ─────────────────────────────────────────────────────────────────────
  "NSA-AI-SECURITY|NSA Cybersecurity Information Sheet: Deploying AI Systems Securely|https://media.defense.gov/2024/Apr/15/2003439257/-1/-1/0/CSI-DEPLOYING-AI-SYSTEMS-SECURELY.PDF"
  "NSA-LLMTHREAT|NSA/CISA: Cybersecurity Advisory on LLM Integration Threats|https://www.nsa.gov/Press-Room/Cybersecurity-Advisories-Guidance/"

  # ── FBI ─────────────────────────────────────────────────────────────────────
  "FBI-DEEPSEEK|FBI Warning: Security Risks of DeepSeek and Chinese-Origin AI Models (Feb 2025)|https://www.ic3.gov/"
  "FBI-FOREIGN-AI|FBI/CISA Advisory: Foreign State-Sponsored AI Tool Threats to U.S. Organizations|https://www.fbi.gov/investigate/counterintelligence/the-china-threat"

  # ── DoD / CMMC ──────────────────────────────────────────────────────────────
  "CMMC-2.0|DoD Cybersecurity Maturity Model Certification (CMMC) 2.0|https://dodcio.defense.gov/CMMC/"
  "DOD-AI-ETHICS|DoD AI Ethical Principles (Adopted Feb 2020)|https://www.ai.mil/docs/Ethical_Principles_for_Artificial_Intelligence.pdf"
  "DFARS-252.204|DFARS 252.204-7012: Safeguarding Covered Defense Information (CUI)|https://www.acquisition.gov/dfars/252.204-7012-safeguarding-covered-defense-information-and-cyber-incident-reporting."
  "DOD-DISA-STIG|DISA Application Security & Development STIG (applies to AI/ML components)|https://public.cyber.mil/stigs/"

  # ── FedRAMP ──────────────────────────────────────────────────────────────────
  "FEDRAMP-AI|FedRAMP Guidance on AI/ML Services Authorization|https://www.fedramp.gov/ai/"

  # ── Congressional / Legislative ─────────────────────────────────────────────
  "NDAA-AI-SEC|National Defense Authorization Act AI Security Provisions (FY2024, Sec. 1553)|https://www.congress.gov/bill/118th-congress/house-bill/2670"
  "AI-ACT-SENATE|Bipartisan Senate AI Policy Roadmap (May 2024)|https://www.schumer.senate.gov/imo/media/doc/ai_policy_roadmap_may2024.pdf"
  "HOUSE-DEEPSEEK|House Select Committee on CCP: Letter on DeepSeek Risks (Jan 2025)|https://selectcommittee.house.gov/"

  # ── FISMA / FCA ──────────────────────────────────────────────────────────────
  "FISMA-2014|Federal Information Security Modernization Act (FISMA) of 2014|https://www.cisa.gov/topics/cyber-threats-and-advisories/federal-information-security-modernization-act"

)

# ─── PRINT REFERENCES FOOTER ──────────────────────────────────────────────────
print_federal_references() {
    local CYAN='\033[0;36m'; local BOLD='\033[1m'; local NC='\033[0m'
    local YELLOW='\033[1;33m'

    echo ""
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║          U.S. FEDERAL GUIDANCE REFERENCES                        ║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo -e "  The controls in this tool are informed by the following federal"
    echo -e "  guidance documents.  Federal contractors handling CUI, operating"
    echo -e "  under DFARS clauses, or subject to CMMC must comply with the"
    echo -e "  applicable frameworks listed below."
    echo ""

    local CATEGORY=""
    for ref in "${FEDERAL_REFERENCES[@]}"; do
        local ID="${ref%%|*}"; local REST="${ref#*|}"
        local TITLE="${REST%%|*}"; local URL="${REST##*|}"

        # Print category headers
        case "$ID" in
            NIST*)   [[ "$CATEGORY" != "NIST" ]]   && { echo -e "  ${BOLD}NIST AI Framework & Controls${NC}"; CATEGORY="NIST"; } ;;
            EO*)     [[ "$CATEGORY" != "EO" ]]     && { echo -e "\n  ${BOLD}Executive Orders${NC}"; CATEGORY="EO"; } ;;
            OMB*)    [[ "$CATEGORY" != "OMB" ]]    && { echo -e "\n  ${BOLD}OMB Policy Memoranda${NC}"; CATEGORY="OMB"; } ;;
            CISA*)   [[ "$CATEGORY" != "CISA" ]]   && { echo -e "\n  ${BOLD}CISA Advisories & Guidance${NC}"; CATEGORY="CISA"; } ;;
            NSA*)    [[ "$CATEGORY" != "NSA" ]]    && { echo -e "\n  ${BOLD}NSA Cybersecurity Guidance${NC}"; CATEGORY="NSA"; } ;;
            FBI*)    [[ "$CATEGORY" != "FBI" ]]    && { echo -e "\n  ${BOLD}FBI / IC Warnings${NC}"; CATEGORY="FBI"; } ;;
            CMMC*|DOD*|DFARS*) [[ "$CATEGORY" != "DOD" ]] && { echo -e "\n  ${BOLD}DoD / CMMC / DFARS${NC}"; CATEGORY="DOD"; } ;;
            FEDRAMP*) [[ "$CATEGORY" != "FED" ]]  && { echo -e "\n  ${BOLD}FedRAMP${NC}"; CATEGORY="FED"; } ;;
            NDAA*|AI-ACT*|HOUSE*) [[ "$CATEGORY" != "LEG" ]] && { echo -e "\n  ${BOLD}Congressional & Legislative${NC}"; CATEGORY="LEG"; } ;;
            FISMA*)  [[ "$CATEGORY" != "FISMA" ]] && { echo -e "\n  ${BOLD}FISMA${NC}"; CATEGORY="FISMA"; } ;;
        esac

        printf "    ${YELLOW}[%-20s]${NC} %s\n" "$ID" "$TITLE"
        printf "    %-22s %s\n" "" "$URL"
        echo ""
    done

    echo -e "  ${BOLD}Quick Reference: Key Applicable Controls${NC}"
    echo ""
    echo "    Localhost-only binding  → NIST SP 800-53 SC-7 (Boundary Protection)"
    echo "    Authentication required → NIST SP 800-53 IA-2, IA-3"
    echo "    Encryption in transit   → NIST SP 800-53 SC-8, SC-28"
    echo "    Audit logging           → NIST SP 800-53 AU-2, AU-12"
    echo "    Model provenance        → NIST AI 600-1 §2.5 (Supply Chain)"
    echo "    Foreign model ban       → FBI Advisory Feb 2025, HOUSE-DEEPSEEK"
    echo "    CUI handling            → NIST SP 800-171 §3.1-3.14, DFARS 252.204-7012"
    echo "    CMMC Level 2+           → CMMC 2.0 Practice AC.L2-3.1.3, CM.L2-3.4.6"
    echo "    MCP / plugin risk       → NIST AI 100-2 (adversarial ML), NSA-AI-SECURITY"
    echo ""
}

# ─── COMPACT INLINE CITATION ──────────────────────────────────────────────────
# Usage: cite "NIST SP 800-53 SC-7" — prints a bracketed inline reference
cite() {
    echo -e "  \033[0;33m[REF: $1]\033[0m"
}
