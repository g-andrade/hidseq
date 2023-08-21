defprotocol HidSeq.Formatter do
  def encode!(formatter, integer)

  def decode(formatter, formatted)
end
