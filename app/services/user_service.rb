class UserService

  def self.signup(params)
    user = User.new(params)
    if user.save
      { success: true, message: "User registered successfully", user: user }
    else
      { success: false, error: user.errors.full_messages.join(", ") }
    end
  end


  
  def self.login(email,password)
    user = User.find_by(email:email)
    if user&.authenticate(password)
      token =JwtService.encode({user_id:user.id})
      {success:true,user: user,token: token}
    else
      {success:false,error: "Invalid email or password"}
   end
 end



end