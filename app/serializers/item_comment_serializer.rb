# frozen_string_literal: true

# JSON-LD representation of an ItemComment (schema.org/Comment).
class ItemCommentSerializer
  def self.call(comment)
    JsonLd.compact(
      "@type" => "Comment",
      "author" => { "@type" => "Person", "name" => comment.author },
      "text" => comment.comment,
      "dateCreated" => JsonLd.time(comment.created_at),
      "dateModified" => JsonLd.time(comment.updated_at)
    )
  end
end
