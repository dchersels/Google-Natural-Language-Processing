{
  title: "Google Natural Language",

  # API key authentication example. See more examples at https://docs.workato.com/developing-connectors/sdk/guides/authentication.html
  connection: {
     fields: [
      {
        name: 'client_id',
        hint: 'Find client ID ' \
          "<a href='https://console.cloud.google.com/apis/credentials' " \
          "target='_blank'>here</a>",
        optional: false
      },
      {
        name: 'client_secret',
        hint: 'Find client secret ' \
          "<a href='https://console.cloud.google.com/apis/credentials' " \
          "target='_blank'>here</a>",
        optional: false,
        control_type: 'password'
      }
    ],

     authorization: {
      type: 'oauth2',

      authorization_url: lambda do |connection|
        scopes = [
          #'https://www.googleapis.com/auth/cloud-platform',
          'https://www.googleapis.com/auth/cloud-language'
        ].join(' ')

        'https://accounts.google.com/o/oauth2/auth?client_id=' \
          "#{connection['client_id']}&response_type=code&scope=#{scopes}" \
          '&access_type=offline&include_granted_scopes=true&prompt=consent'
      end,

      acquire: lambda do |connection, auth_code, redirect_uri|
        response = post('https://accounts.google.com/o/oauth2/token').
                   payload(client_id: connection['client_id'],
                           client_secret: connection['client_secret'],
                           grant_type: 'authorization_code',
                           code: auth_code,
                           redirect_uri: redirect_uri).
                   request_format_www_form_urlencoded
        [response, nil, nil]
      end,

      refresh: lambda do |connection, refresh_token|
        post('https://accounts.google.com/o/oauth2/token').
          payload(client_id: connection['client_id'],
                  client_secret: connection['client_secret'],
                  grant_type: 'refresh_token',
                  refresh_token: refresh_token).
          request_format_www_form_urlencoded
      end,

      refresh_on: [401],

      detect_on: [/"errors"\:\s*\[/],

      apply: lambda do |_connection, access_token|
        headers('Authorization' => "Bearer #{access_token}")
      end
    },
    
   base_uri: lambda do |_connection|
      'https://language.googleapis.com'
    end
  },

  test: lambda do |_connection|
    #get('https://www.googleapis.com/oauth2/v2/userinfo')
  end,

  object_definitions: {
     documentInput: {
      fields: lambda do |_connection, _config_fields|
        [
          { 
            name: "document", 
            type: :object,
            label: "Document",
            hint: "Input document. Deatiled here: https://cloud.google.com/natural-language/docs/reference/rest/v1beta2/documents#Document",
            stickey: true,
            properties: [
              { 
                label: "Document Type",
                name: "type", 
                optional: false,
                control_type: 'select',
                pick_list: 'docTypes',
                default: 'PLAIN_TEXT'
              },
              { name: "content", optional: false },
              { 
                name: "gcsContentUri", 
                hint: "The Google Cloud Storage URI where the file content is located. This URI must be of the form: gs://bucket_name/object_name. For more details, see https://cloud.google.com/storage/docs/reference-uris. NOTE: Cloud Storage object versioning is not supported." },
              { name: "language" }
            ]
          
          },
          { 
            name: "encodingType", 
            optional: false,
            control_type: 'select',
            pick_list: 'encTypes',
            default: 'UTF8'
          }
        ]
      end
    },    
    sentimentResults: {
      fields: lambda do
        [
          {
            name: "documentSentiment",
            label: "Document Sentiment",
            hint: "The overall sentiment of the input document.",
            type: "object",
            properties: [
              {
                name: "magnitude",
                label: "Magnitude",
                type: "number",
                hint: "A non-negative number in the [0, +inf) range, which represents the absolute magnitude of sentiment regardless of score (positive or negative)."
              },
              {
                name: "score",
                label: "Score",
                type: "number",
                hint: "Sentiment score between -1.0 (negative sentiment) and 1.0 (positive sentiment)."                
              }
            ]
          },
          {
            name:"language",
            label: "Detected Language",
            hint: "The language of the text, which will be the same as the language specified in the request or, if not specified, the automatically-detected language."
          },
          { 
            name: "sentences",
            label: "Sentences",
            hint: "The sentiment for all the sentences in the document.",
            type: "array" ,
            of: "object",
              properties: [
              { 
                name: "text",
                label: "Text",
                type: "object",
                properties: [
                  {
                    name: "content",
                    label: "Content",
                    hint: "The content of the output text."
                  },
                  {
                    name: "beginOffset",
                    label: "Begin Offset",
                    hint: "The API calculates the beginning offset of the content in the original document according to the <a href='https://cloud.google.com/natural-language/docs/reference/rest/v1/EncodingType'>EncodingType</a> specified in the API request.",
                    type: "number"
                  }
                ]
              },
              { 
                name: "sentiment",
                label: "Sentiment",
                hint: "Contains the sentiment for the sentence.",
                type: "object",
                properties: [
                  { 
                    name: "magnitude",
                    label: "Magnitude",
                    hint: "A non-negative number in the [0, +inf) range, which represents the absolute magnitude of sentiment regardless of score (positive or negative).",
                    type: "number"
                  },
                  { 
                    name: "score",
                    label: "Score",
                    hint: "Sentiment score between -1.0 (negative sentiment) and 1.0 (positive sentiment).",
                    type: "number"
                  }
                ]
              },
            ]
          }
        ]
      end
    }
  },

  actions: {
    analyze_sentiment: {
      # Define the way people search for your actions and how it looks like on the recipe level
      # See more at https://docs.workato.com/developing-connectors/sdk/sdk-reference/actions.html
      title: "Analyze Sentiment",
      subtitle: "Analyzes the sentiment of the provided text.",
      description: "Analyzes the sentiment of the provided text.",
      help: "This action analyzes the sentiment of the provided text.",

      # The input fields shown for this action. Shows when a user is defining the action.
      # Possible arguements in this specific order - object_definitions
      # See more at https://docs.workato.com/developing-connectors/sdk/sdk-reference/actions.html#input-fields
      input_fields: lambda do |object_definitions|
        object_definitions['documentInput']
      end,

      # This code is run when a recipe uses this action.
      # Possible arguements in this specific order - connection, input, input_schema, output_schema
      # See more at https://docs.workato.com/developing-connectors/sdk/sdk-reference/actions.html#execute
      execute: lambda do |_connection, _input, _input_schema, _output_schema|
        payload = {
          "document":
            {
              "type": _input['document']['type'],
              "language": _input['document']['language'],
              "content": _input['document']['content'],
              "gcsContentUri": _input['document']['gcsContentUri']  
            },
          "encodingType": _input['encodingType']
        };

        post('/v1/documents:analyzeSentiment', payload).
          after_error_response(/.*/) do |_code, body, _header, message|
            error("#{message}: #{body}")
          end
     end,

      # The output values of the action. Shows in the output datatree of a recipe.
      # Possible arguements in this specific order - object_definitions
      # See more at https://docs.workato.com/developing-connectors/sdk/sdk-reference/actions.html#output-fields
      output_fields: lambda do |object_definitions|
        object_definitions["sentimentResults"]
      end,
    }
  },

  pick_lists: {
     encTypes: lambda do |connection|
        [
          ["NONE","NONE"],
          ["UTF8","UTF8"],
          ["UTF16","UTF16"],
          ["UTF32","UTF32"]
        ]
      end,    
    docTypes: lambda do |connection|
        [
          ["The content type is not specified","TYPE_UNSPECIFIED"],
          ["Plain text","PLAIN_TEXT"],
          ["Cloud HTML","HTML"]
        ]
      end

    # folder: lambda do |connection|
    #   get("https://www.wrike.com/api/v3/folders")["data"].
    #     map { |folder| [folder["title"], folder["id"]] }
    # end
  },

  # Reusable methods can be called from object_definitions, picklists or actions
  # See more at https://docs.workato.com/developing-connectors/sdk/sdk-reference/methods.html
  methods: {
  }
}
