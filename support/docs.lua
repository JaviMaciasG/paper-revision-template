-- PDF-only presentation changes; the Markdown sources remain unchanged.
function CodeBlock(block)
  for i, class in ipairs(block.classes) do
    if class == 'tex' then block.classes[i] = 'latex' end
    if class == 'sh' or class == 'shell' then block.classes[i] = 'bash' end
  end
  return {
    pandoc.RawBlock('latex', '\\begin{DocCode}'),
    block,
    pandoc.RawBlock('latex', '\\end{DocCode}')
  }
end

function Code(code)
  -- Permit line breaks inside paths and filenames in narrow table columns.
  if code.text:match('^[%w_./%-%<%>]+$') then
    return pandoc.RawInline('latex', '\\nolinkurl{' .. code.text .. '}')
  end
end

function Link(link)
  local path, fragment = link.target:match('^(README%.md)(.*)$')
  if not path then path, fragment = link.target:match('^(HOWTO%.md)(.*)$') end
  if path then
    path = path:gsub('%.md$', '.pdf')
    link.target = path .. fragment
  end
  return link
end

local function navigation(block)
  if block.t ~= 'BulletList' then return false end
  for _, item in ipairs(block.content) do
    if #item ~= 1 then return false end
    local content = item[1].content
    if not content or #content ~= 1 or content[1].t ~= 'Link' or
       not content[1].target:match('^#') then return false end
  end
  return true
end

function Pandoc(document)
  if document.blocks[1] and document.blocks[1].t == 'Header' and
     document.blocks[1].level == 1 then
    document.meta.title = pandoc.MetaInlines(document.blocks[1].content)
    document.blocks:remove(1)
  end
  document.meta.date = pandoc.MetaInlines({})
  local blocks = pandoc.List()
  local started = false
  for _, block in ipairs(document.blocks) do
    if block.t == 'Header' then
      -- Begin section 1 on a new page before creating its hyperlink anchor.
      if not started then
        blocks:insert(pandoc.RawBlock('latex', '\\clearpage'))
      end
      started = true
      block.level = math.max(1, block.level - 1)
      -- Reserve space before the hyperlink anchor, so jumps land on the heading's page.
      blocks:insert(pandoc.RawBlock('latex', '\\Needspace{' .. math.max(4, 7 - block.level) .. '\\baselineskip}'))
    end
    if started or not navigation(block) then blocks:insert(block) end
  end
  document.blocks = blocks
  return document
end
