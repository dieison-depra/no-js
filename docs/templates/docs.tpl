<div class="page-wrapper">
<link rel="preload" href="assets/docs.css" as="style" onload="this.rel='stylesheet'">
<!-- Documentation — Single page with all sections -->

<!-- Reusable skeleton — injected by NoJS via template[include] -->
<template id="doc-skeleton">
  <div class="doc-skeleton"><span class="skl-badge"></span><div class="skl-h1"></div><div class="skl-sub"></div><div class="skl-code"></div><div class="skl-h2"></div><div class="skl-line"></div><div class="skl-line w85"></div><div class="skl-line w65"></div><div class="skl-code sm"></div></div>
</template>

<div class="doc-with-sidebar">

    <div class="sidebar-skeleton">
        <div class="sidebar-skeleton-inner">
            <div class="skl-sidebar-group"><div class="skl-sidebar-title"></div><div class="skl-sidebar-link"></div><div class="skl-sidebar-link w75"></div><div class="skl-sidebar-link w85"></div><div class="skl-sidebar-link w65"></div></div>
            <div class="skl-sidebar-group"><div class="skl-sidebar-title"></div><div class="skl-sidebar-link"></div><div class="skl-sidebar-link w85"></div><div class="skl-sidebar-link w75"></div><div class="skl-sidebar-link"></div><div class="skl-sidebar-link w65"></div></div>
            <div class="skl-sidebar-group"><div class="skl-sidebar-title"></div><div class="skl-sidebar-link w85"></div><div class="skl-sidebar-link"></div><div class="skl-sidebar-link w75"></div></div>
            <div class="skl-sidebar-group"><div class="skl-sidebar-title"></div><div class="skl-sidebar-link"></div><div class="skl-sidebar-link w75"></div><div class="skl-sidebar-link w65"></div><div class="skl-sidebar-link w85"></div></div>
        </div>
    </div>
    <template src="./docs/sidebar.tpl"></template>

    <div class="doc-main">

        <div id="getting-started"><template src="./docs/getting-started.tpl" loading="#doc-skeleton"></template></div>

        <div id="cheatsheet"><template src="./docs/cheatsheet.tpl" loading="#doc-skeleton"></template></div>
        <div id="actions-refs"><template src="./docs/actions-refs.tpl" loading="#doc-skeleton"></template></div>
        <div id="custom-directives"><template src="./docs/custom-directives.tpl" loading="#doc-skeleton"></template></div>
        <div id="error-handling"><template src="./docs/error-handling.tpl" loading="#doc-skeleton"></template></div>
        <div id="configuration"><template src="./docs/configuration.tpl" loading="#doc-skeleton"></template></div>
        <div id="state-management"><template src="./docs/state-management.tpl" loading="#doc-skeleton"></template></div>

        <div id="events"><template src="./docs/events.tpl" loading="#doc-skeleton"></template></div>
        <div id="data-binding"><template src="./docs/data-binding.tpl" loading="#doc-skeleton"></template></div>
        <div id="conditionals"><template src="./docs/conditionals.tpl" loading="#doc-skeleton"></template></div>
        <div id="loops"><template src="./docs/loops.tpl" loading="#doc-skeleton"></template></div>
        <div id="templates"><template src="./docs/templates.tpl" loading="#doc-skeleton"></template></div>
        <div id="data-fetching"><template src="./docs/data-fetching.tpl" loading="#doc-skeleton"></template></div>
        <div id="routing"><template src="./docs/routing.tpl" loading="#doc-skeleton"></template></div>
        <div id="forms-validation"><template src="./docs/forms-validation.tpl" loading="#doc-skeleton"></template></div>
        <div id="styling"><template src="./docs/styling.tpl" loading="#doc-skeleton"></template></div>
        <div id="drag-and-drop"><template src="./docs/drag-and-drop.tpl" loading="#doc-skeleton"></template></div>
        <div id="animations"><template src="./docs/animations.tpl" loading="#doc-skeleton"></template></div>
        <div id="filters"><template src="./docs/filters.tpl" loading="#doc-skeleton"></template></div>
        <div id="i18n"><template src="./docs/i18n.tpl" loading="#doc-skeleton"></template></div>

    </div><!-- /doc-main -->
</div><!-- /doc-with-sidebar -->
</div>

