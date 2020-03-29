require 'date'
require 'csv'
require 'net/http'

BASE_SITE = URI('http://services.runescape.com/m=itemdb_oldschool')

URL_LIST = [
	'/Rune+platelegs/viewitem?obj=1079', #Rune platelegs
	'/Rune+plateskirt/viewitem?obj=1093', #Rune plateskirt
	'/Rune+chainbody/viewitem?obj=1113', #Rune chainbody
	'/Rune+platebody/viewitem?obj=1127', #Rune platebody
	'/Rune+med+helm/viewitem?obj=1147', #Rune med helm
	'/Rune+full+helm/viewitem?obj=1163', #Rune full helm
	'/Rune+sq+shield/viewitem?obj=1185', #Rune square shield
	'/Rune+kiteshield/viewitem?obj=1201', #Rune kiteshield
	'/Rune+sword/viewitem?obj=1289', #Rune sword
	'/Rune+longsword/viewitem?obj=1303', #Rune longsword
	'/Rune+2h+sword/viewitem?obj=1319', #Rune 2h sword
	'/Rune+scimitar/viewitem?obj=1333', #Rune scimitar
	'/Dragon+med+helm/viewitem?obj=1149', #Dragon med helm
	'/Dragon+sq+shield/viewitem?obj=1187', #Dragon sq shield
	'/Dragon+longsword/viewitem?obj=1305', #Dragon longsword
	'/Dragon+battleaxe/viewitem?obj=1377', #Dragon battleaxe
	'/Dragon+mace/viewitem?obj=1434', #Dragon mace
	'/Dragon+platelegs/viewitem?obj=4087', #Dragon platelegs
	'/Dragon+plateskirt/viewitem?obj=4585', #Dragon plateskirt
	'/Dragon+scimitar/viewitem?obj=4587', #Dragon scimitar (Goes above and below alch profitability) ------------------------ HIGH VOLUME ITEMS BELOW
	'/Nature+rune/viewitem?obj=561', #Nature rune
	'/Coal/viewitem?obj=453', #Coal
	'/Battlestaff/viewitem?obj=1391', #Battlestaff
	'/Cannonball/viewitem?obj=2', #Cannonball
	'/Adamant+dart/viewitem?obj=810', #Adamant dart
	'/Bow+string/viewitem?obj=1777' #Bow string
].freeze

STORED_MATCHES = []

class DataFetcher
	def fetch(url_info)
		uri = URI("#{BASE_SITE}#{url_info}")
		response = Net::HTTP.get_response(uri)
		return response
	end

	def parse_html(html)
		item_data = []
		date_data = []
		html.each do |row|	
			# trade prices
			attempted_match_average = row.match('average180.push.*;')
			date_data = date_data + parse_average_prices(attempted_match_average) if attempted_match_average

			#STORED_MATCHES << attempted_match_trade if attempted_match_trade
			
			# concats average price
			attempted_match_trade = row.match('trade180.push.*;')
			if attempted_match_trade
				date_data = date_data + parse_trade_prices(attempted_match_trade)
				item_data << date_data
				date_data = []
			end
		end
		return item_data
	end
	
	def parse_trade_prices(trade_data)
		# example input data: ["trade180.push([new", "Date('2019/11/08'),", "40040853]);"]
		init_split = trade_data.string.split
		amount_traded = (init_split[2].split"]")[0]
		return([amount_traded.to_i])		
	end
	
	def parse_average_prices(averages_data)
		init_split = averages_data.string.split
		trade_date = (init_split[1].split"'")[1].gsub(/\//, '-')
		daily_average = (init_split[2].split",")[0]
		six_month_trend = (init_split[3].split"]")[0] 
		return([trade_date,daily_average.to_i,six_month_trend.to_i])
	end
	
	def split_html(body)
		body.split("\n")
	end

	def main()
		CSV.open("data/full_item_list.csv", 'wb') do |fullCSV|
			fullCSV << ["Date", "Daily Average", "Six Month Average", "Amount Traded", "Item ID"]
			URL_LIST.each do |url_data|
				item_id = (url_data.split"=")[1]
				CSV.open("data/#{item_id}_runescape_GE_item_prices.csv", 'wb') do |csv|
					csv << ["Date", "Daily Average", "Six Month Average", "Amount Traded"]

					fail_count = 0

					response = fetch(url_data)
					until response.code == '200'
						sleep 1
						fail_count++
						response = fetch(url_data)
						if fail_count > 4
							puts "Failed 5 times while trying to gather #{item_id}."
							exit
						end
					end
		
					parsed_html = parse_html(split_html(response.body))
					parsed_html.each do |row|
						csv << row

						# Append the item id when adding to the full url file.
						row << item_id
						fullCSV << row
					end

					sleep 1
				end
			end
		end
	end
end

fetcher = DataFetcher.new
fetcher.main()
