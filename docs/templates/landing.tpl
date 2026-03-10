<div class="page-wrapper">
<link rel="preload" href="assets/landing.css" as="style" onload="this.rel='stylesheet'">
<!-- Landing Page - from design.pen V7 "The Full Story" (bAp6a) -->

<!-- ═══ Section 1: Code Comparison - #F8FAFC bg, padding 80, gap 40 ═══ -->
<section class="v7-code-compare">
  <h2 class="v7-code-compare-title" t="landing.codeCompare.title" t-html></h2>
  <p class="v7-code-compare-sub" t="landing.codeCompare.subtitle"></p>
  <div class="v7-panels">
    <div class="v7-panel">
      <div class="v7-panel-topbar">
        <span class="v7-panel-label v7-panel-label--react" t="landing.codeCompare.reactLabel"></span>
        <span class="v7-panel-meta" t="landing.codeCompare.reactMeta"></span>
      </div>
      <pre class="v7-panel-code"><span class="v7-ln"> 1</span><span class="hl-kw">import</span> { useState, useEffect } <span class="hl-kw">from</span> <span class="hl-str">'react'</span>;
<span class="v7-ln"> 2</span>
<span class="v7-ln"> 3</span><span class="hl-kw">const</span> <span class="hl-fn">Search</span> = () =&gt; {
<span class="v7-ln"> 4</span>  <span class="hl-kw">const</span> [query, setQuery] = <span class="hl-fn">useState</span>(<span class="hl-str">''</span>);
<span class="v7-ln"> 5</span>  <span class="hl-kw">const</span> [results, setResults] = <span class="hl-fn">useState</span>([]);
<span class="v7-ln"> 6</span>
<span class="v7-ln"> 7</span>  <span class="hl-fn">useEffect</span>(() =&gt; {
<span class="v7-ln"> 8</span>    <span class="hl-kw">if</span> (!query) <span class="hl-kw">return</span>;
<span class="v7-ln"> 9</span>    <span class="hl-fn">fetch</span>(<span class="hl-str">`/api/search?q=</span><span class="hl-op">${</span>query<span class="hl-op">}</span><span class="hl-str">`</span>)
<span class="v7-ln">10</span>      .then(r =&gt; r.json())
<span class="v7-ln">11</span>      .then(setResults);
<span class="v7-ln">12</span>  }, [query]);
<span class="v7-ln">13</span>
<span class="v7-ln">14</span>  <span class="hl-kw">return</span> (
<span class="v7-ln">15</span>    <span class="hl-tag">&lt;div&gt;</span>
<span class="v7-ln">16</span>      <span class="hl-tag">&lt;input</span>
<span class="v7-ln">17</span>        <span class="hl-attr">value</span>=<span class="hl-str">{query}</span>
<span class="v7-ln">18</span>        <span class="hl-attr">onChange</span>=<span class="hl-str">{e =&gt; setQuery(e.target.value)}</span>
<span class="v7-ln">19</span>      <span class="hl-tag">/&gt;</span>
<span class="v7-ln">20</span>      {results.map(r =&gt; (
<span class="v7-ln">21</span>        <span class="hl-tag">&lt;li</span> <span class="hl-attr">key</span>=<span class="hl-str">{r.id}</span><span class="hl-tag">&gt;</span>{r.name}<span class="hl-tag">&lt;/li&gt;</span>
<span class="v7-ln">22</span>      ))}
<span class="v7-ln">23</span>    <span class="hl-tag">&lt;/div&gt;</span>
<span class="v7-ln">24</span>  );
<span class="v7-ln">25</span>};</pre>
    </div>
    <div class="v7-panel">
      <div class="v7-panel-topbar">
        <span class="v7-panel-label v7-panel-label--nojs" t="landing.codeCompare.nojsLabel"></span>
        <span class="v7-panel-meta" t="landing.codeCompare.nojsMeta"></span>
      </div>
      <pre class="v7-panel-code v7-panel-code--nojs"><span class="v7-ln">1</span><span class="hl-tag">&lt;div</span> <span class="hl-attr">state</span>=<span class="hl-str">"{ query: '' }"</span> <span class="hl-attr">get</span>=<span class="hl-str">"/api/search?q={{ query }}"</span> <span class="hl-attr">as</span>=<span class="hl-str">"results"</span><span class="hl-tag">&gt;</span>
<span class="v7-ln">2</span>  <span class="hl-tag">&lt;input</span> <span class="hl-attr">model</span>=<span class="hl-str">"query"</span> <span class="hl-tag">/&gt;</span>
<span class="v7-ln">3</span>  <span class="hl-tag">&lt;li</span> <span class="hl-attr">each</span>=<span class="hl-str">"r in results"</span> <span class="hl-attr">bind</span>=<span class="hl-str">"r.name"</span><span class="hl-tag">&gt;&lt;/li&gt;</span>
<span class="v7-ln">4</span><span class="hl-tag">&lt;/div&gt;</span></pre>
      <span class="v7-panel-note" t="landing.codeCompare.nojsNote"></span>
    </div>
  </div>
</section>

<!-- ═══ Section 2: Bundle Stats - white bg, padding 100/80, gap 24, centered ═══ -->
<section class="v7-bundle">
  <span class="v7-bundle-badge" t="landing.bundle.badge"></span>
  <h2 class="v7-bundle-h1" t="landing.bundle.h1"></h2>
  <h2 class="v7-bundle-h2" t="landing.bundle.h2"></h2>
  <p class="v7-bundle-sub" t="landing.bundle.subtitle"></p>
  <div class="v7-bundle-btns">
    <a route="/docs" class="btn btn-primary" t="landing.bundle.getStarted"></a>
    <a route="/features" class="btn btn-secondary" t="landing.bundle.seeFeatures"></a>
  </div>
</section>

<!-- ═══ Section 3: Philosophy Hero - #0F172A bg, padding 120/80/100/80, gap 32 ═══ -->
<section class="v7-manifesto">
  <span class="v7-kicker" t="landing.manifesto.kicker"></span>
  <h1 class="v7-manifesto-h1" t="landing.manifesto.h1"></h1>
  <h2 class="v7-manifesto-h2" t="landing.manifesto.h2"></h2>
  <div class="v7-divider"></div>
</section>

<!-- ═══ Section 4: Problem Editorial - #0F172A bg, padding 80, gap 60 ═══ -->
<section class="v7-problem">
  <span class="v7-kicker" t="landing.problem.kicker"></span>
  <div class="v7-columns">
    <div class="v7-column">
      <p t="landing.problem.col1p1"></p>
      <p t="landing.problem.col1p2"></p>
    </div>
    <div class="v7-column">
      <p t="landing.problem.col2p1"></p>
      <p t="landing.problem.col2p2"></p>
    </div>
    <div class="v7-column">
      <p t="landing.problem.col3p1"></p>
      <p t="landing.problem.col3p2"></p>
    </div>
  </div>
</section>

<!-- ═══ Section 5: Principles - #0A1020 bg, padding 80, gap 48 ═══ -->
<section class="v7-principles">
  <span class="v7-kicker" t="landing.principles.kicker"></span>
  <div class="v7-principles-grid">
    <div class="v7-principle-card">
      <span class="v7-principle-num">01</span>
      <h3 class="v7-principle-title" t="landing.principles.p1Title"></h3>
      <p class="v7-principle-desc" t="landing.principles.p1Desc"></p>
    </div>
    <div class="v7-principle-card">
      <span class="v7-principle-num">02</span>
      <h3 class="v7-principle-title" t="landing.principles.p2Title"></h3>
      <p class="v7-principle-desc" t="landing.principles.p2Desc"></p>
    </div>
    <div class="v7-principle-card">
      <span class="v7-principle-num">03</span>
      <h3 class="v7-principle-title" t="landing.principles.p3Title"></h3>
      <p class="v7-principle-desc" t="landing.principles.p3Desc"></p>
    </div>
    <div class="v7-principle-card">
      <span class="v7-principle-num">04</span>
      <h3 class="v7-principle-title" t="landing.principles.p4Title"></h3>
      <p class="v7-principle-desc" t="landing.principles.p4Desc"></p>
    </div>
  </div>
</section>

<!-- ═══ Section 6: Pull Quote - #F8FAFC bg, padding 80/160, centered ═══ -->
<section class="v7-quote">
  <blockquote class="v7-quote-text" t="landing.quote" t-html></blockquote>
</section>

<!-- ═══ Section 7: CTA - #0F172A bg, padding 80, gap 20, centered ═══ -->
<section class="landing-cta">
  <h2 class="landing-cta-headline" t="landing.cta.headline"></h2>
  <p class="landing-cta-sub" t="landing.cta.subtitle"></p>
  <div class="cta-buttons">
    <a route="/docs" class="btn btn-cta-primary" t="landing.cta.getStarted"></a>
    <a route="/features" class="btn btn-ghost" t="landing.cta.learnMore"></a>
  </div>
</section>
</div>
