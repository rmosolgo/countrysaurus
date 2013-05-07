@nice_money = (amount, options={}) ->
	# Props to akmiller for original code -- I'm using it all the time though so hosting it here.
	full_label = options.full_label || false
	if d3?
		if 1000 >= amount 
			label = ""
			money = d3.format("0,r")(d3.round(amount,0))
		else if 1000000 > amount >= 1000
			label = (if full_label then "Thousand" else "K" )
			money = d3.round((amount/1000),0)
		else if 1000000000 > amount >= 1000000
			label = (if full_label then "Million" else "M")
			money = d3.round((amount/1000000),1)
		else if amount >= 1000000000
			label = (if full_label then "Billion" else "B")
			money = d3.format("0,r")(d3.round((amount/1000000000),2))
		else
			label = ""
			money = amount

		money + " " + label
	else
		console.log "nice_money requires D3"
		amount

@split_to_fit = (string, allowable_width) ->
  # console.log("splitting '#{string}' to fit #{allowable_width}")
  splitters = [' ', ',', '-', '.'] # allowable splitters
  new_strings = []
  for w in [allowable_width..0]
    # console.log("trying width=#{w}, which returns '#{string[w]}'")
    if string[w] in splitters
      # console.log("found a splitter at #{w} in #{string}")
      if string[w] is ' '
        end_of_word = w-1
      else 
        end_of_word = w
      new_strings.push string[0..end_of_word]
      shorter_string = string[w+1..]
      if shorter_string.length > allowable_width
        next_split = split_to_fit(shorter_string, allowable_width)
        # console.log("split_to_fit is joining in", next_split, " to ", new_strings)
        new_strings = new_strings.concat(next_split)
        # console.log("after joining in", next_split, ", split_to_fit has ", new_strings)
      else 
        new_strings.push shorter_string
      break
    else if w is 0
      # If you didn't find a break on the inside, 
      # then get desperate and search for a break on the outside.
      for w2 in [0..string.length]
        if string[w2] in splitters
          if string[w2] is ' '
            end_of_word = w2-1
          else 
            end_of_word = w2
          new_strings.push string[0..end_of_word]
          shorter_string = string[w2+1..] 
          if shorter_string.length > allowable_width
            next_split = split_to_fit(shorter_string, allowable_width)
            # console.log("split_to_fit is joining in", next_split, " to ", new_strings)
            new_strings = new_strings.concat(next_split)
            # console.log("after joining in", next_split, ", split_to_fit has ", new_strings)
          else 
            new_strings.push shorter_string
          break   
        else if w2 == string.length 
          # If you still don't find one, then return the string without a break.
          # console.log("no split found in '#{string}', returning it anyways!")
          new_strings.push string
  # console.log('split_to_fit is returning', new_strings)
  return new_strings