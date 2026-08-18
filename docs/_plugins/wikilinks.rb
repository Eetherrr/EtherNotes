# frozen_string_literal: true

# EtherNotes — Obsidian 风格 wikilink 转换器
#
# 在渲染前把 Obsidian 语法转成 Jekyll/kramdown 能处理的形式：
#   [[目标|别名]]        → <a href="...">别名</a>
#   [[目标]]             → <a href="...">目标</a>
#   ![[图片.png]]        → <img src="..." alt="图片.png" />
#   ![[图片.png|宽度]]   → <img src="..." alt="图片.png" width="宽度" />
#
# 目标解析：
#   - 文章链接目标 = 文章 frontmatter 的 title 或文件名（不含扩展名）
#   - 图片目标 = docs/assets/ 下的静态文件名（basename → 路径）
#
# 转换发生两次（双保险）：
#   1. pre_render：改写 Markdown（跳过 ```/~~~ 代码块），
#      让 kramdown 直接看到干净的语法；
#   2. post_render：兜底清理输出 HTML 里残留的 [[...]]（跳过 <pre> 块）。

module EtherNotes
  module Wikilinks
    IMG_RE  = /!\[\[([^\]|]+?)(?:\|(\d+))?\]\]/
    LINK_RE = /\[\[([^\]|]+?)(?:\|([^\]]+))?\]\]/

    module_function

    # ---- 索引（按 site 缓存一次） ----

    def maps(site)
      cached = site.data["wikilinks_maps"]
      return cached if cached

      post_map = {}
      site.posts.docs.each do |doc|
        post_map[doc.basename] = doc.url
        title = doc.data["title"]
        post_map[title] = doc.url if title
      end

      asset_map = {}
      site.static_files.each do |f|
        next unless f.relative_path.start_with?("/assets/")

        asset_map[f.basename] = site.baseurl.to_s + f.relative_path
      end

      site.data["wikilinks_maps"] = [post_map, asset_map]
    end

    # ---- 替换逻辑 ----

    def img_replace(m, _post_map, asset_map)
      name  = m[1].strip
      width = m[2]
      url   = asset_map[name]
      if url && !url.empty?
        attrs = width ? %( width="#{width}") : ""
        %(<img src="#{url}" alt="#{name}"#{attrs} />)
      else
        missing(:image, name)
      end
    end

    def link_replace(m, post_map, _asset_map)
      target = m[1].strip
      alias_ = m[2] && m[2].strip
      url = post_map[target]
      if url
        text = alias_.nil? || alias_.empty? ? target : alias_
        %(<a href="#{url}">#{text}</a>)
      else
        missing(:link, alias_ || target)
      end
    end

    # 输出不含 [[...]]，避免再被后续 gsub 二次匹配
    def missing(kind, name)
      label = kind == :image ? "图片缺失" : "链接缺失"
      %(<span class="wikilink-missing" data-wikilink="#{name}" title="#{label}: #{name}">#{label}: #{name}</span>)
    end

    # ---- Markdown（pre_render） ----

    def transform_markdown(content, post_map, asset_map)
      return content unless content.include?("[[")
      return content if content.include?("```") || content.include?("~~~")

      content.gsub(IMG_RE) { img_replace(Regexp.last_match, post_map, asset_map) }
             .gsub(LINK_RE) { link_replace(Regexp.last_match, post_map, asset_map) }
    end

    # ---- HTML（post_render，兜底） ----

    def transform_html(html, post_map, asset_map)
      return html unless html.include?("[[")

      segments = html.split(%r{(<pre[\s>].*?</pre>)}m)
      segments.map! do |seg|
        if seg.start_with?("<pre")
          seg
        else
          seg.gsub(IMG_RE) { img_replace(Regexp.last_match, post_map, asset_map) }
             .gsub(LINK_RE) { link_replace(Regexp.last_match, post_map, asset_map) }
        end
      end
      segments.join
    end
  end
end

Jekyll::Hooks.register [:posts, :pages], :pre_render do |doc, _payload|
  next unless doc.respond_to?(:content) && doc.content.is_a?(String)

  post_map, asset_map = EtherNotes::Wikilinks.maps(doc.site)
  doc.content = EtherNotes::Wikilinks.transform_markdown(doc.content, post_map, asset_map)
end

Jekyll::Hooks.register [:posts, :pages], :post_render do |doc, _payload|
  next unless doc.respond_to?(:output) && doc.output.is_a?(String)

  post_map, asset_map = EtherNotes::Wikilinks.maps(doc.site)
  doc.output = EtherNotes::Wikilinks.transform_html(doc.output, post_map, asset_map)
end
