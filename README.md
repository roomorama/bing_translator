Bing Translator 
===============

This gem is forked from Codeblock/bing_translator-gem, translate_array functionality is added.
Nokogiri and JSON version dependencies are relaxed to 1.5.4 and 1.7.7 respectively.

Getting a Client ID and Secret
==============================

To sign up for the free tier (as of this writing), do the following:

1. Go [here](http://go.microsoft.com/?linkid=9782667)
2. Sign in with valid MSN credentials.
3. On the right side, click 'SIGN UP', under the $0.00 option.
4. Read and accept the terms and conditions and click the big 'SIGN UP'
   button.
5. [Create a new application](https://datamarket.azure.com/developer/applications).
   Fill in a unique client ID, give it a valid name, give it a valid redirect
   URI (not actually used by the Bing Translator API, so it can be anything)
   and hit 'CREATE'.
6. Click on the name of your application to see the info again. You'll need
   the 'Client ID' and 'Client secret' fields.

Usage
=====

```ruby
require 'rubygems'
require 'bing_translator'
translator = BingTranslator.new('YOUR_CLIENT_ID', 'YOUR_CLIENT_SECRET')
spanish = translator.translate 'Hello. This will be translated!', :from => 'en', :to => 'es'
spanish_array = translator.translate_array ["hello", "bye"], from: en, to: es

# without :from for auto language detection
spanish = translator.translate 'Hello. This will be translated!', :to => 'es'

locale = translator.detect 'Hello. This will be translated!' # => :en

# The speak method calls a text-to-speech interface in the supplied language.
# It does not translate the text. Format can be 'audio/mp3' or 'audio/wav'

audio = translator.speak 'Hello. This will be spoken!', :language => :en, :format => 'audio/mp3', :options => 'MaxQuality'
open('file.mp3', 'wb') { |f| f.write audio }

```
