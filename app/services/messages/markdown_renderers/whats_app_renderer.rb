class Messages::MarkdownRenderers::WhatsAppRenderer < Messages::MarkdownRenderers::BaseMarkdownRenderer
  def initialize
    super
    @list_item_number = 0
  end

  def strong(_node)
    out('*', :children, '*')
  end

  def emph(_node)
    out('_', :children, '_')
  end

  def code(node)
    out('`', node.string_content, '`')
  end

  def code_block(node)
    out('```', node.string_content, '```')
    cr
  end

  def strikethrough(_node)
    out('~', :children, '~')
  end

  def link(node)
    out(:children, ' (', node.url, ')')
  end

  def blockquote(_node)
    out(:children)
  end

  def list(node)
    @list_type = node.list_type
    @list_item_number = @list_type == :ordered_list ? node.list_start : 0
    out(:children)
    cr
  end

  def list_item(_node)
    if @list_type == :ordered_list
      out("#{@list_item_number}. ", :children)
      @list_item_number += 1
    else
      out('• ', :children)
    end
    cr
  end

  def header(_node)
    out('*', :children, '*')
    cr
  end

  def softbreak(_node)
    out("\n")
  end
end
