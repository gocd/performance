require  'nokogiri'
xml_doc = Nokogiri::XML(File.open("jmeter.jtl"))
xml_doc.xpath('//failure').each do |failure_attribute|
  if failure_attribute.text == 'true'
    puts failure_attribute.parent.parent
    exit 1
  end
end