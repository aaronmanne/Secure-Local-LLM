# =============================================================================
# common/references.ps1
# U.S. Federal regulatory citations and guidance references relevant to
# securing local LLM software.  Dot-sourced by all Windows scripts.
# =============================================================================

# ─── CITATION DATABASE ────────────────────────────────────────────────────────
$FederalReferences = @(
    # NIST
    [PSCustomObject]@{ Category='NIST'; ID='NIST AI 100-1';    Title='NIST AI Risk Management Framework (AI RMF 1.0)';                             URL='https://doi.org/10.6028/NIST.AI.100-1' }
    [PSCustomObject]@{ Category='NIST'; ID='NIST AI 100-2';    Title='NIST Adversarial Machine Learning: Taxonomy and Terminology';                URL='https://doi.org/10.6028/NIST.AI.100-2' }
    [PSCustomObject]@{ Category='NIST'; ID='NIST AI 600-1';    Title='NIST AI RMF for Generative AI';                                             URL='https://doi.org/10.6028/NIST.AI.600-1' }
    [PSCustomObject]@{ Category='NIST'; ID='NIST SP 800-53r5'; Title='Security & Privacy Controls for Information Systems (Rev 5)';                URL='https://doi.org/10.6028/NIST.SP.800-53r5' }
    [PSCustomObject]@{ Category='NIST'; ID='NIST SP 800-171r3';Title='Protecting CUI in Nonfederal Systems (Rev 3)';                               URL='https://doi.org/10.6028/NIST.SP.800-171r3' }
    [PSCustomObject]@{ Category='NIST'; ID='NIST SP 800-218';  Title='Secure Software Development Framework (SSDF)';                               URL='https://doi.org/10.6028/NIST.SP.800-218' }
    # Executive Orders
    [PSCustomObject]@{ Category='EO';   ID='EO 14110';         Title='EO on Safe, Secure, and Trustworthy AI (Oct 30, 2023)';                      URL='https://www.whitehouse.gov/briefing-room/presidential-actions/2023/10/30/executive-order-on-the-safe-secure-and-trustworthy-development-and-use-of-artificial-intelligence/' }
    [PSCustomObject]@{ Category='EO';   ID='EO 14179';         Title='EO: Removing Barriers to American Leadership in AI (Jan 23, 2025)';          URL='https://www.whitehouse.gov/presidential-actions/2025/01/removing-barriers-to-american-leadership-in-artificial-intelligence/' }
    # OMB
    [PSCustomObject]@{ Category='OMB';  ID='OMB M-24-10';      Title='Advancing Governance, Innovation, and Risk Management for Agency AI Use';    URL='https://www.whitehouse.gov/wp-content/uploads/2024/03/M-24-10-Advancing-Governance-Innovation-and-Risk-Management.pdf' }
    [PSCustomObject]@{ Category='OMB';  ID='OMB M-24-18';      Title='Improving Security of Federal Systems and Related AI Guidance';              URL='https://www.whitehouse.gov/wp-content/uploads/2024/07/M-24-18-Securing-the-US-Government-Use-of-AI.pdf' }
    # CISA
    [PSCustomObject]@{ Category='CISA'; ID='CISA AI-ROADMAP';  Title='CISA Roadmap for Artificial Intelligence 2023-2024';                         URL='https://www.cisa.gov/sites/default/files/2023-11/2023-2024-CISA-Roadmap-for-AI.pdf' }
    [PSCustomObject]@{ Category='CISA'; ID='CISA-LLMSEC';      Title='CISA/UK NCSC: Guidelines for Secure AI System Development';                  URL='https://www.cisa.gov/sites/default/files/2023-11/guidelines_for_secure_ai_system_development_508c.pdf' }
    [PSCustomObject]@{ Category='CISA'; ID='CISA-AI-THREATS';  Title='CISA Guidance on Defending AI Systems Against Adversarial Attacks';          URL='https://www.cisa.gov/ai' }
    # NSA
    [PSCustomObject]@{ Category='NSA';  ID='NSA-AI-SECURITY';  Title='NSA CSI: Deploying AI Systems Securely';                                     URL='https://media.defense.gov/2024/Apr/15/2003439257/-1/-1/0/CSI-DEPLOYING-AI-SYSTEMS-SECURELY.PDF' }
    [PSCustomObject]@{ Category='NSA';  ID='NSA-LLMTHREAT';    Title='NSA/CISA Cybersecurity Advisory on LLM Integration Threats';                 URL='https://www.nsa.gov/Press-Room/Cybersecurity-Advisories-Guidance/' }
    # FBI
    [PSCustomObject]@{ Category='FBI';  ID='FBI-DEEPSEEK';     Title='FBI Warning: Security Risks of DeepSeek and Chinese-Origin AI (Feb 2025)';   URL='https://www.ic3.gov/' }
    [PSCustomObject]@{ Category='FBI';  ID='FBI-FOREIGN-AI';   Title='FBI/CISA Advisory: Foreign State-Sponsored AI Tool Threats';                 URL='https://www.fbi.gov/investigate/counterintelligence/the-china-threat' }
    # DoD / CMMC
    [PSCustomObject]@{ Category='DoD';  ID='CMMC-2.0';         Title='DoD Cybersecurity Maturity Model Certification (CMMC) 2.0';                  URL='https://dodcio.defense.gov/CMMC/' }
    [PSCustomObject]@{ Category='DoD';  ID='DOD-AI-ETHICS';    Title='DoD AI Ethical Principles (Feb 2020)';                                       URL='https://www.ai.mil/docs/Ethical_Principles_for_Artificial_Intelligence.pdf' }
    [PSCustomObject]@{ Category='DoD';  ID='DFARS-252.204';    Title='DFARS 252.204-7012: Safeguarding Covered Defense Information (CUI)';         URL='https://www.acquisition.gov/dfars/252.204-7012-safeguarding-covered-defense-information-and-cyber-incident-reporting.' }
    [PSCustomObject]@{ Category='DoD';  ID='DISA-STIG';        Title='DISA Application Security & Development STIG';                               URL='https://public.cyber.mil/stigs/' }
    # FedRAMP
    [PSCustomObject]@{ Category='FedRAMP'; ID='FEDRAMP-AI';    Title='FedRAMP Guidance on AI/ML Services Authorization';                           URL='https://www.fedramp.gov/ai/' }
    # Legislative
    [PSCustomObject]@{ Category='Legislative'; ID='NDAA-AI-SEC';  Title='NDAA FY2024 AI Security Provisions (Sec. 1553)';                          URL='https://www.congress.gov/bill/118th-congress/house-bill/2670' }
    [PSCustomObject]@{ Category='Legislative'; ID='AI-ACT-SENATE';Title='Bipartisan Senate AI Policy Roadmap (May 2024)';                          URL='https://www.schumer.senate.gov/imo/media/doc/ai_policy_roadmap_may2024.pdf' }
    [PSCustomObject]@{ Category='Legislative'; ID='HOUSE-DEEPSEEK';Title='House Select Committee on CCP: Letter on DeepSeek Risks (Jan 2025)';    URL='https://selectcommittee.house.gov/' }
    # FISMA
    [PSCustomObject]@{ Category='FISMA'; ID='FISMA-2014';      Title='Federal Information Security Modernization Act (FISMA) of 2014';             URL='https://www.cisa.gov/topics/cyber-threats-and-advisories/federal-information-security-modernization-act' }
)

# ─── PRINT REFERENCES FOOTER ──────────────────────────────────────────────────
function Show-FederalReferences {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          U.S. FEDERAL GUIDANCE REFERENCES                        ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "  The controls in this tool are informed by the following federal"
    Write-Host "  guidance documents. Federal contractors handling CUI, operating"
    Write-Host "  under DFARS clauses, or subject to CMMC must comply with the"
    Write-Host "  applicable frameworks listed below."
    Write-Host ""

    $currentCat = ''
    foreach ($ref in $FederalReferences) {
        if ($ref.Category -ne $currentCat) {
            Write-Host ""
            Write-Host "  $($ref.Category)" -ForegroundColor White
            $currentCat = $ref.Category
        }
        Write-Host ("    [{0,-20}] {1}" -f $ref.ID, $ref.Title) -ForegroundColor Yellow
        Write-Host ("    {0,-22} {1}" -f '', $ref.URL)
        Write-Host ""
    }

    Write-Host "  Key Applicable Controls" -ForegroundColor White
    Write-Host ""
    Write-Host "    Localhost-only binding   -> NIST SP 800-53 SC-7 (Boundary Protection)"
    Write-Host "    Authentication required  -> NIST SP 800-53 IA-2, IA-3"
    Write-Host "    Encryption in transit    -> NIST SP 800-53 SC-8, SC-28"
    Write-Host "    Audit logging            -> NIST SP 800-53 AU-2, AU-12"
    Write-Host "    Model provenance         -> NIST AI 600-1 Section 2.5 (Supply Chain)"
    Write-Host "    Foreign model ban        -> FBI Advisory Feb 2025, HOUSE-DEEPSEEK"
    Write-Host "    CUI handling             -> NIST SP 800-171 Sections 3.1-3.14, DFARS 252.204-7012"
    Write-Host "    CMMC Level 2+            -> CMMC 2.0 AC.L2-3.1.3, CM.L2-3.4.6"
    Write-Host "    MCP / plugin risk        -> NIST AI 100-2, NSA-AI-SECURITY"
    Write-Host ""
}
