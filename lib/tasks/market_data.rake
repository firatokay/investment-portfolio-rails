namespace :market_data do
  desc "Update exchange rates for all forex pairs"
  task update_exchange_rates: :environment do
    puts "🔄 Updating exchange rates..."

    forex_pairs = [
      { from: 'USD', to: 'TRY' },
      { from: 'EUR', to: 'TRY' },
      { from: 'EUR', to: 'USD' },
      { from: 'GBP', to: 'USD' },
      { from: 'USD', to: 'JPY' }
    ]

    service = MarketData::ForexDataService.new
    summary = { total: forex_pairs.count, success: 0, failed: 0, errors: [] }

    forex_pairs.each do |pair|
      begin
        count = service.update_rate_history(
          from_currency: pair[:from],
          to_currency: pair[:to],
          days: 1  # Only fetch latest rate
        )

        if count > 0
          summary[:success] += 1
          puts "  ✓ #{pair[:from]}/#{pair[:to]}: #{count} rates updated"
        else
          summary[:failed] += 1
          summary[:errors] << "#{pair[:from]}/#{pair[:to]}: No data returned"
          puts "  ✗ #{pair[:from]}/#{pair[:to]}: No data returned"
        end

        # Rate limiting: 1 second between API calls
        sleep(1)
      rescue => e
        summary[:failed] += 1
        summary[:errors] << "#{pair[:from]}/#{pair[:to]}: #{e.message}"
        puts "  ✗ #{pair[:from]}/#{pair[:to]}: #{e.message}"
      end
    end

    puts "\n✅ Exchange rate update completed!"
    puts "   Total: #{summary[:total]}, Success: #{summary[:success]}, Failed: #{summary[:failed]}"

    if summary[:errors].any?
      puts "\nErrors:"
      summary[:errors].each { |error| puts "  - #{error}" }
    end
  end

  desc "Update latest prices for all assets in positions"
  task update_position_prices: :environment do
    puts "🔄 Updating prices for all position assets..."

    assets = Asset.joins(:positions).distinct
    summary = { total: assets.count, success: 0, failed: 0, errors: [] }

    assets.find_each do |asset|
      begin
        result = MarketData::HistoricalPriceFetcher.fetch_for_asset(asset, days: 1)

        if result > 0
          summary[:success] += 1
          puts "  ✓ #{asset.symbol}: Updated"
        else
          summary[:failed] += 1
          summary[:errors] << "#{asset.symbol}: No data returned"
          puts "  ✗ #{asset.symbol}: No data returned"
        end

        # Rate limiting: 1 second between API calls
        sleep(1)
      rescue => e
        summary[:failed] += 1
        summary[:errors] << "#{asset.symbol}: #{e.message}"
        puts "  ✗ #{asset.symbol}: #{e.message}"
      end
    end

    puts "\n✅ Price update completed!"
    puts "   Total: #{summary[:total]}, Success: #{summary[:success]}, Failed: #{summary[:failed]}"

    if summary[:errors].any?
      puts "\nErrors:"
      summary[:errors].each { |error| puts "  - #{error}" }
    end
  end

  desc "Full market data update (exchange rates + position prices)"
  task update_all: :environment do
    puts "🚀 Starting full market data update...\n"

    Rake::Task['market_data:update_exchange_rates'].invoke
    puts "\n" + "="*50 + "\n"
    Rake::Task['market_data:update_position_prices'].invoke

    puts "\n🎉 Full market data update completed!"
  end
end
