require 'test_helper'

class GroupsControllerTest < ActionController::TestCase
  setup do
    login(users(:valid))
    @group = groups(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:groups)
  end

  # test "should get new" do
  #   get :new
  #   assert_response :success
  # end
  
  test "should create group and generate stickies" do
    assert_difference('Sticky.count', templates(:one).items.size) do
      assert_difference('Group.count') do
        post :create, template_id: templates(:one).to_param, frame_id: frames(:one).to_param
      end
    end
    assert_not_nil assigns(:template)
    assert_not_nil assigns(:group)
    assert_equal templates(:one).items.size, assigns(:group).stickies.size
    assert_equal assigns(:frame), frames(:one)
    assert_equal assigns(:frame_id).to_s, frames(:one).to_param
    assert_equal assigns(:group).user_id.to_s, users(:valid).to_param
    assert_redirected_to group_path(assigns(:group))
  end

  test "should not create group and generate stickies for invalid template id" do
    assert_difference('Sticky.count', 0) do
      assert_difference('Group.count', 0) do
        post :create, template_id: -1, frame_id: frames(:one).to_param
      end
    end
    assert_nil assigns(:template)
    assert_nil assigns(:frame)
    assert_nil assigns(:frame_id)
    assert_redirected_to root_path
  end
  
  test "should show group" do
    get :show, id: @group.to_param
    assert_response :success
  end
  
  test "should get edit" do
    get :edit, id: @group.to_param
    assert_response :success
  end
  
  test "should update group" do
    put :update, id: @group.to_param, group: { description: "Group Description Update" }
    assert_not_nil assigns(:group)
    assert_equal [@group.project_id], assigns(:group).stickies.collect{|s| s.project_id}.uniq
    assert_equal [frames(:one).to_param], assigns(:group).stickies.collect{|s| s.frame_id.to_s}.uniq
    assert_redirected_to group_path(assigns(:group))
  end

  test "should update group and move group and stickies to another project" do
    put :update, id: @group.to_param, group: { description: "Group Description Update", project_id: projects(:two).to_param }
    assert_not_nil assigns(:group)
    assert_equal [projects(:two).to_param], assigns(:group).stickies.collect{|s| s.project_id.to_s}.uniq
    assert_equal [nil], assigns(:group).stickies.collect{|s| s.frame_id}.uniq
    assert_redirected_to group_path(assigns(:group))
  end

  test "should not update group with blank project" do
    put :update, id: @group.to_param, group: { description: 'Group Description Update', project_id: nil }
    assert_not_nil assigns(:group)
    assert assigns(:group).errors.size > 0
    assert_equal ["can't be blank"], assigns(:group).errors[:project_id]
    assert_template 'edit'
  end
  
  test "should not update group with invalid id" do
    put :update, :id => -1, group: { description: "Group Description Update" }
    assert_nil assigns(:group)
    assert_redirected_to root_path
  end
  
  test "should destroy group and attached stickies" do
    assert_difference('Sticky.current.count', -1 * @group.stickies.size) do
      assert_difference('Group.current.count', -1) do
        delete :destroy, :id => @group.to_param
      end
    end
    
    assert_equal 0, assigns(:group).stickies.size
    assert_redirected_to groups_path
  end
  
  test "should not destroy with invalid id" do
    assert_difference('Sticky.current.count', 0) do
      assert_difference('Group.current.count', 0) do
        delete :destroy, :id => -1
      end
    end
    
    assert_nil assigns(:group)
    assert_redirected_to root_path
  end
end
