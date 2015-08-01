#!/bin/env ruby
# encoding: utf-8

require 'colorize'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'pry'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

def xml_from(url)
  doc = Nokogiri::XML(open(url).read)
  doc.remove_namespaces!
  doc
end

def gender_from(str)
  return unless str
  return 'male' if str == 'mann'
  return 'female' if str == 'kvinne'
  raise "unknown gender: #{str}"
end

def date_from(str)
  return unless str
  DateTime.parse(str).to_date.to_s
end

def scrape_term(t)
  puts t[:id]
  url = 'http://data.stortinget.no/eksport/representanter?stortingsperiodeid=%s' % t[:id]
  xml = xml_from(url)

  xml.xpath('.//representant').each do |p|
    field = ->(n) { p.xpath(n).text }

    data = { 
      id: field.('id'),
      given_name: field.('fornavn'),
      family_name: field.('etternavn'),
      name: "%s %s" % [field.('fornavn'), field.('etternavn')],
      sort_name: "%s, %s" % [field.('etternavn'), field.('fornavn')],
      birth_date: date_from(field.('foedselsdato')),
      gender: gender_from(field.('kjoenn')),
      area: field.('fylke/navn'),
      area_id: field.('fylke/id'),
      party: field.('parti/navn'),
      party_id: field.('parti/id'),
      term: t[:id],
      source: url,
    }
    if t[:id][0...4].to_i >= 1997
      data[:image] = 'http://data.stortinget.no/eksport/personbilde?personid=%s&storrelse=middels' % data[:id] 
    end
    puts data
    ScraperWiki.save_sqlite([:id, :term], data)
  end
end

termdata = xml_from('http://data.stortinget.no/eksport/stortingsperioder')
termdata.xpath('.//stortingsperiode').each do |t|
  t = {
    id: t.xpath('id').text,
    name: t.xpath('id').text,
    start_date: date_from(t.xpath('fra').text),
    end_date: date_from(t.xpath('til').text),
  }
  ScraperWiki.save_sqlite([:id], t, 'terms')
  scrape_term(t)
end

