# frozen_string_literal: true

# EtherNotes — Obsidian 风格 wikilink 转换器
#
# 在 kramdown 渲染之前，把 Obsidian 语法重写为标准 Markdown/HTML：
#   [[目标|别名]]        → <a href="...">别名</a>
#   [[目标]]             → <a href="...">目标</a>
#   ![[图片.png]]        → <img src="..." alt="图片.png" />
#   ![[图片.png|宽度]]   → <img src="..." alt="图片.png" width="宽度" />
#
# 目标解析：
#   - 文章链接目标 = 文章 frontmatter 的 title 或文件名（不含扩展名）
#   - 图片目标 = docs/assets/ 下的静态文件名（basename → 路径）
#
# 时机：`:site, :post_read`（所有文档读取完成后、任何渲染发生之前），
#       直接改写 document.content，kramdown 只会看到干净的内容。
#       逐行跳过 ```/~~~ 代码围栏与缩进代码块，避免误伤代码。

module EtherNotes
  module Wikilinks
    IMG_RE  = /!\[\[([^\]|]+?)(?:\|(\d+))?\]\]/
    LINK_RE = /\[\[([^\]|]+?)(?:\|([^\]]+))?\]\]/

    module_function

    # ---- 索引（构建一次，挂在 site.data 上） ----

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
        # Jekyll 4 的 relative_path 不带前导斜杠（"assets/images/x.png"）
        next unless f.relative_path.start_with?("assets/")

        asset_map[f.basename] = [site.baseurl.to_s, f.relative_path].join("/")
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

    # 输出不含 [[...]]，避免被后续 gsub 二次匹配
    def missing(kind, name)
      label = kind == :image ? "图片缺失" : "链接缺失"
      %(<span class="wikilink-missing" data-wikilink="#{name}" title="#{label}: #{name}">#{label}: #{name}</span>)
    end

    # ---- Markdown 转换（逐行，跳过代码块） ----

    def transform_markdown(content, post_map, asset_map)
      return content unless content.include?("[[")

      in_fence = false
      content.each_line.map do |line|
        if line =~ /^\s*(```|~~~)/
          in_fence = !in_fence
          line
        elsif in_fence || line =~ /^( {4}|\t)/
          # 代码围栏内 / 缩进代码块：原样保留
          line
        else
          line.gsub(IMG_RE) { img_replace(Regexp.last_match, post_map, asset_map) }
              .gsub(LINK_RE) { link_replace(Regexp.last_match, post_map, asset_map) }
        end
      end.join
    end
  end
end

Jekyll::Hooks.register :site, :post_read do |site|
  post_map, asset_map = EtherNotes::Wikilinks.maps(site)

  (site.posts.docs + site.pages).each do |doc|
    next unless doc.respond_to?(:content) && doc.content.is_a?(String)

    doc.content = EtherNotes::Wikilinks.transform_markdown(doc.content, post_map, asset_map)
  end
end
