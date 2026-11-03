app_styles <- tags$head(tags$style(HTML("
  /* Selectors that compete with Bootstrap defaults (.well, a:hover) are doubled
     or list their :hover/:focus states so they win regardless of load order. */

  .umn-banner {
    width: 100%;
    background-color: #7A0019;
    padding: 6px 24px;
  }
  .umn-banner img {
    height: 30px;
  }

  .navbar-logo {
    height: 30px;
    margin-right: 10px;
    vertical-align: middle;
  }
  .navbar-title {
    font-weight: 600;
    font-size: 20px;
    vertical-align: middle;
  }

  .about-intro {
    margin-bottom: 10px;
    width: 100%;
    font-size: 14px;
    line-height: 1.5;
    color: #333;
  }
  .callout {
    margin-top: 10px;
    margin-bottom: 16px;
    padding: 12px 14px;
    background-color: #f7f7f7;
    border-left: 4px solid #1E3A66;
  }
  .info-block {
    margin-top: 6px;
    margin-bottom: 14px;
    font-size: 14px;
    line-height: 1.5;
    color: #333;
  }

  .tab-intro {
    margin-bottom: 12px;
  }
  .tab-intro p {
    font-size: 14px;
    line-height: 1.5;
    color: #444;
  }
  .proximity-intro {
    margin-bottom: 10px;
  }
  .proximity-intro p {
    color: #555;
    line-height: 1.45;
    margin-top: 0;
    margin-bottom: 6px;
  }

  .sidebar-heading {
    font-weight: 600;
    margin-bottom: 4px;
  }
  .map-title {
    font-weight: 600;
  }

  .epicurve-panel {
    margin-bottom: 25px;
  }
  .epicurve-panel h4 {
    font-weight: 600;
    color: #1E3A66;
  }
  .epicurve-panel hr {
    border-top: 2px solid #1E3A66;
    margin-top: 25px;
  }
  .color-key-intro {
    margin-bottom: 14px;
    font-size: 13.5px;
    line-height: 1.55;
    color: #333;
  }
  .coverage-badge {
    display: inline-block;
    padding: 1px 7px;
    border-radius: 3px;
    font-size: 12.5px;
  }

  .proximity-search-heading {
    margin-top: 0;
    margin-bottom: 15px;
  }
  .address-search {
    margin-bottom: 10px;
  }
  .proximity-filters {
    padding-top: 15px;
  }
  .proximity-results-note {
    color: #666;
    font-size: 14px;
    margin-bottom: 15px;
  }

  details {
    border: 1px solid #0008CA8;
    border-radius: 4px;
    margin-bottom: 8px;
    padding: 8px 12px;
    background-color: #E0F2F5;
  }
  details summary {
    cursor: pointer;
    font-weight: 500;
    color: #003865;
  }
  details[open] summary {
    margin-bottom: 8px;
    color: #008CA8;
  }
  details p, details ul {
    color: #333;
    margin-top: 8px;
  }

  .well.resource-card {
    background-color: #f7f7f7;
    border-color: #1E3A66;
    border-size: 5px;
    font-size: 14px;
    height: 75px;
    display: flex;
    flex-direction: column;
    text-align: center;
    justify-content: center;
    align-items: center;
    margin-top: 10px;
    margin-bottom: 16px;
    padding: 12px 14px;
    font-weight: 500;
  }
  .resource-card a,
  .resource-card a:hover,
  .resource-card a:focus {
    color: #003865;
  }

  .footer {
    text-align: center;
    max-width: 900px;
    margin-left: auto;
    margin-right: auto;
  }
  .footer-main {
    margin-top: 40px;
  }
  .footer-resources {
    margin-top: 10px;
  }
  .footer-text {
    font-size: 12.5px;
    color: #555;
    line-height: 1.55;
    text-align: left;
  }
  .footer-text a,
  .footer-text a:hover,
  .footer-text a:focus {
    color: #0066cc;
  }
  .footer-logos {
    display: flex;
    justify-content: center;
    align-items: center;
    gap: 40px;
    margin-top: 25px;
  }
  .footer-resources .footer-logos {
    margin-bottom: 25px;
  }
  .footer-logos img {
    height: 50px;
  }
  .footer-updated {
    font-size: 12.5px;
    color: gray;
    margin-top: 10px;
    font-style: italic;
  }
  .submap-title {
    font-weight: 600;
  }
  .submap-coverage-display {
    font-size:14px;
    color:#555;
    margin-bottom:8px;
  }
  .legend-box {
      background: white;
      padding: 6px;
      border-radius: 4px;
      font-size: 13px;
    }
  .grade-details-heading {
    font-weight: 600;
  }
  .grade-details-facility {
    white-space: normal;
    word-break: break-word;
    font-size: 18px;
    margin-bottom: 12px;
  }
  .grade-details-details {
    margin-top: -8px;
    margin-bottom: 12px;
  }
  .grade-details-bullet {
    list-style-type: none;
    padding-left: 1.5rem;
    margin-top: -8px;
    margin-bottom: 12px;
  }
  .grade-details-footnote {
    margin-top: 10px;
    font-style: italic;
  }
  
")))