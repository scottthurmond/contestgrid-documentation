# ADR 0020: Non-Intrusive Advertising Platform (Public Portal)

## Status
Accepted

## Context
Public portal (read-only schedules, standings, rankings, team pages) attracts sports enthusiasts and families. Opportunity to monetize via non-intrusive, contextually relevant advertising from sports equipment vendors, apparel brands, and local restaurants/venues. Ads should not annoy or distract from core content; limited to public portal (not paid league/officials portals).

## Decision
Implement an advertising platform on the public portal with careful placement, frequency caps, and contextual relevance. Support multiple ad formats (banners, sponsored listings, native content). Offer tiered pricing for advertisers. Keep ads non-intrusive and relevant to users.

## Advertising Strategy

### Ad Placement (Non-Intrusive)
**Allowed Placements:**
- **Sidebar ads** (right/left column on desktop, below content on mobile): 300×250, 160×600, 300×600
- **Below-fold content**: appear after primary content is consumed (user scrolls past main info)
- **Sponsored team/league cards**: "Featured this week" section highlighting partner teams/vendors
- **Contextual listings**: inline with search results (e.g., "Nearby restaurants" or "Sports equipment retailers")
- **Footer banner**: wide banner at very bottom of page (728×90, 970×90)

**Prohibited Placements (To Avoid Annoyance):**
- Pop-ups or interstitials (except optional dismiss-able banners for major sponsors)
- Auto-play video
- Floating/sticky ads that follow user scrolling
- Ads covering content (lightbox style)
- Full-page takeovers
- Sound/audio without explicit user click

### Frequency Capping
- Max 3 ad placements per page view
- Max 5 page views per user session before ad-free break (e.g., user can view 5 pages, then ad-free for 3 pages)
- Rotating ad pools: no single advertiser shown >2 times per session
- Daily cap: user sees each unique advertiser max 3 times per day

### Ad Types & Formats

**1. Banner Ads**
- Static image or animated GIF (no video)
- Sizes: 728×90 (leaderboard), 300×250 (medium rectangle), 300×600 (half page), 160×600 (wide skyscraper)
- Click-through to advertiser landing page or app store
- Typical inventory: 10–20 slots per day (rotated)

**2. Sponsored Listings/Native Content**
- Styled to match platform design (labeled "Sponsored" clearly)
- Examples:
  - "Featured Sports Equipment Partner: Dick's Sporting Goods" (with logo, short description, link)
  - "Top-Rated Local Restaurant: Jimmy's Pizza House" (with location, link)
  - "Official Apparel Partner: Team Uniforms Plus"
- Appear in contextual sections (e.g., "Partners & Sponsors" footer on league pages)
- Clickable cards with advertiser branding

**3. Search & Contextual Ads**
- When user searches for "sporting goods near me": show relevant local retailers (Google Maps API integration)
- "Restaurants near [venue]": sponsored links to local restaurants
- "Team uniforms": sponsored apparel retailers
- Clearly marked as "Sponsored Results"

**4. Seasonal/Event-Based Ads**
- Back-to-school sports equipment (Aug–Sept)
- Holiday gift guides (Nov–Dec)
- Spring sports season prep (Feb–March)
- Advertiser can define seasonal campaigns and budgets

### Advertiser Onboarding & Categories

**Advertiser Categories:**
- Sports equipment & apparel (Dick's Sporting Goods, Spalding, Nike, etc.)
- Local restaurants & venues (near game venues)
- Sports services (coaching, camps, sports medicine)
- Travel & transportation (car rentals for tournament travel)
- Sponsorships & partnerships (brands aligned with youth/amateur sports)

**Prohibited Categories:**
- Alcohol, tobacco, gambling (except where legally permitted and age-gated)
- Cryptocurrencies, MLM schemes, predatory lending
- Political campaigns, religious organizations (debatable; generally avoided)
- Adult content

### Pricing Models

**Model #1: CPM (Cost Per Thousand Impressions)**
- Advertiser pays per 1000 views of their ad
- Standard rates: $2–5 CPM (sports/equipment segment)
- Local businesses (restaurants): $1–3 CPM
- Premium inventory (homepage, featured): $5–10 CPM
- Minimum spend: $500/month

**Model #2: CPC (Cost Per Click)**
- Advertiser pays only when user clicks through
- Rates: $0.10–0.50 per click (depending on category)
- Local restaurants/services: $0.05–0.15 per click
- Performance-based; lower commitment risk for advertiser

**Model #3: CPA (Cost Per Action) / Affiliate**
- Advertiser pays when user completes action (purchase, signup, store visit)
- Rates: 5–15% commission on transaction value
- Best for e-commerce (apparel retailers, equipment)
- Requires integration with advertiser shop/app

**Model #4: Sponsorship (Fixed Monthly Fee)**
- Fixed monthly fee for dedicated ad placement or season-long exposure
- Rates: $1,000–5,000/month (depending on placement and duration)
- Guaranteed impressions or placements per month
- Ideal for major brands (league/regional level)

**Advertiser Tiers:**
- **Starter**: $500/month, 2 ad placements, CPM model (2000–3000 impressions/day)
- **Growth**: $2,000/month, 4 ad placements, CPM + CPC mix, custom landing page tracking
- **Premium**: $5,000+/month, featured sponsorship, branded hub/section, priority support, analytics dashboard
- **Affiliate**: Revenue share (5–15%), pay-per-action, tech integration

### Ad Inventory & Management

**Self-Service Ad Platform (Future):**
- Advertiser dashboard: upload creatives, set budget, define targeting (age, location, interests)
- Budget controls: daily/monthly caps, pause/resume campaigns
- Analytics: impressions, clicks, CTR, conversions (if integrated)
- Scheduling: define start/end dates, seasonal campaigns
- A/B testing: test multiple creatives; platform selects best performer

**Manual/Managed Service (MVP):**
- Platform sales team manages advertiser onboarding
- Creative approval process (brand safety)
- Monthly reporting with impressions/clicks/CTR
- Billing and reconciliation

### Targeting & Relevance

**Contextual Targeting:**
- Equipment ads on game/team pages
- Restaurant ads on league pages/maps
- Apparel ads on standing/leaderboard pages

**Location-Based:**
- Show local restaurants/services near game venues
- Local sports retailers for nearby users
- Privacy-respecting (user opt-in for location; anonymized)

**Behavioral (Privacy-Safe):**
- If user viewing youth football content → show youth equipment ads
- User on tournament page → show travel/lodging ads
- User on team roster → show apparel ads
- NO personal data tracking; segment-based only

### Data & Privacy

**User Privacy:**
- No individual user tracking (no cookies, pixels)
- Segment-based targeting only (e.g., "users viewing youth sports")
- Anonymized impression logging (IP hash, not stored)
- GDPR/CCPA compliant: no personal data to advertisers
- Clear disclosure: "Ads help keep Contest Schedule free for public users"

**Advertiser Data:**
- Provide aggregate stats only (impressions, clicks, CTR)
- No personal user data shared with advertisers
- Advertiser must agree to privacy policy and data use terms

### Brand Safety & Content Moderation

**Ad Review Process:**
1. Advertiser submits creative and landing page
2. Automated scan for malware/suspicious links
3. Manual review by team (brand alignment, content safety)
4. Approval or rejection with feedback
5. Creative re-review if advertiser updates

**Prohibited Content:**
- Misleading claims or false advertising
- Hate speech or discriminatory content
- Links to phishing/malware sites
- Adult or inappropriate content
- Excessive flashing/animation (accessibility)

**Monitoring & Takedown:**
- User reports inappropriate ads → review and remove within 24h
- Regular audits of live ads
- Automatic disable for broken/malicious links

## Revenue Model & Projections

### Base Calculations:
- Public portal: 10,000 unique users/month (conservative estimate, grows over time)
- Average 5 page views per user/month = 50,000 monthly impressions
- CPM rate: $3 average
- **Base revenue**: 50,000 impressions / 1000 × $3 = **$150/month**

### Scaled Projections (Year 1→3):
- **Year 1**: 10k users, $150–300/month ad revenue (low), experimental
- **Year 2**: 50k users, $750–1,500/month (5 advertisers average), more competitive
- **Year 3**: 200k+ users, $3,000–6,000/month (10–15 active advertisers), sustainable revenue stream

### Ad Revenue Sharing (Optional):
- Keep 70% of ad revenue; offer 30% to league tenants (as incentive for public portal participation)
- Example: league gets $50/month if users visit their public page from ad clicks
- Encourages tenants to promote public portal participation

## Advertiser Benefits & Partnerships

**Co-Marketing Opportunities:**
- Sponsor featured tournament or league (branded page section)
- Logo on leaderboard or standings page
- Newsletter mentions (if/when platform has email list)
- Social media shout-outs

**Product Integration (Optional):**
- "Dick's Sporting Goods equipment list" linked to game teams (teams list gear recommendations)
- "Local restaurants" section on venue pages
- Affiliate links for equipment recommendations in how-to guides

## Exemptions & Controls

**League Admin Controls (For Paid Tenants):**
- Leagues can request advertiser exclusions (e.g., "no competitor ads")
- Leagues can opt-out of affiliate commissions if brand conflict
- Can disable ads on their league's public pages (premium feature option)

**Officials Portal & Paid Areas:**
- Zero ads in league-admin, officials-admin portals
- No ads for paying tenants
- Maintains clean, professional experience for paying customers

## Implementation Phases

**Phase 1 (MVP):** Manual, single advertiser, test CPM model
- One sports equipment retailer (partner), 2-3 banner placements
- Manual reporting, $500–1,000/month revenue test
- Validate user experience and feedback

**Phase 2:** Expand to 3–5 advertisers, self-service basics
- Advertiser dashboard (basic budget controls)
- Ad network management tool
- Monthly reporting; CPC model option
- Target $3,000–5,000/month

**Phase 3:** Full self-service platform, advanced targeting
- Automated approval workflow
- Real-time analytics and performance tracking
- A/B testing and optimization
- Multiple pricing models (CPM, CPC, CPA)
- Target $10,000+/month

## Consequences
- **Pros**: new revenue stream (50–100% pure margin once platform built); serves advertisers in sports ecosystem; enhances public portal value without annoying paying customers; sustainable long-term business model.
- **Cons**: requires careful design to avoid user backlash; brand safety and moderation overhead; technical platform buildout; mitigated by phased rollout and clear brand guidelines.
