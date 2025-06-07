BOT_NAME = 'apilinkscraper'

SPIDER_MODULES = ['apilinkscraper.spiders']
NEWSPIDER_MODULE = 'apilinkscraper.spiders'

# Zyte Cloud optimizations
ROBOTSTXT_OBEY = True
DOWNLOAD_DELAY = 1
RANDOMIZE_DOWNLOAD_DELAY = True
CONCURRENT_REQUESTS = 8
CONCURRENT_REQUESTS_PER_DOMAIN = 2

USER_AGENT = 'apilinkscraper (+https://scrapinghub.com)'

# Enable and configure HTTP caching
HTTPCACHE_ENABLED = True
HTTPCACHE_EXPIRATION_SECS = 3600

# Disable cookies if not needed  
COOKIES_ENABLED = False

# Request headers
DEFAULT_REQUEST_HEADERS = {
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en',
}

# Autothrottle settings
AUTOTHROTTLE_ENABLED = True
AUTOTHROTTLE_START_DELAY = 1
AUTOTHROTTLE_MAX_DELAY = 3
AUTOTHROTTLE_TARGET_CONCURRENCY = 2.0

# Memory usage optimization
MEMUSAGE_ENABLED = True
MEMUSAGE_LIMIT_MB = 2048
MEMUSAGE_WARNING_MB = 1024

# Retry settings
RETRY_ENABLED = True
RETRY_TIMES = 2
RETRY_HTTP_CODES = [500, 502, 503, 504, 408, 429]

# Logging
LOG_LEVEL = 'INFO'

# Output settings
FEEDS = {
    'apis_and_links.json': {
        'format': 'json',
        'overwrite': True,
    },
}
