class StickiesController < ApplicationController
  before_filter :authenticate_user!

  def search
    current_user.update_attribute :stickies_per_page, params[:stickies_per_page].to_i if params[:stickies_per_page].to_i >= 10 and params[:stickies_per_page].to_i <= 200
    @project = current_user.all_viewable_projects.find_by_id(params[:project_id])
    if @project
      @frame = Frame.find_by_id(params[:frame_id])
      @order = Sticky.column_names.collect{|column_name| "stickies.#{column_name}"}.include?(params[:order].to_s.split(' ').first) ? params[:order] : "(status = 'completed') ASC, (status = 'ongoing') DESC, due_date ASC, end_date DESC, start_date DESC"
      sticky_scope = @project.stickies.with_frame(params[:frame_id])
      sticky_scope = sticky_scope.order(@order)
      @stickies = sticky_scope.page(params[:page]).per(current_user.stickies_per_page)
      render "projects/show"
    else
      redirect_to root_path
    end
  end
    
  def index
    current_user.update_attribute :stickies_per_page, params[:stickies_per_page].to_i if params[:stickies_per_page].to_i >= 10 and params[:stickies_per_page].to_i <= 200
    @order = Sticky.column_names.collect{|column_name| "stickies.#{column_name}"}.include?(params[:order].to_s.split(' ').first) ? params[:order] : "(status = 'completed') ASC, (status = 'ongoing') DESC, due_date ASC, end_date DESC, start_date DESC"
    sticky_scope = current_user.all_viewable_stickies
    @search_terms = params[:search].to_s.gsub(/[^0-9a-zA-Z]/, ' ').split(' ')
    @search_terms.each{|search_term| sticky_scope = sticky_scope.search(search_term) }
    sticky_scope = sticky_scope.order(@order)
    @stickies = sticky_scope.page(params[:page]).per(current_user.stickies_per_page)
  end

  def show
    @sticky = current_user.all_viewable_stickies.find_by_id(params[:id])
    redirect_to root_path unless @sticky
  end

  def new
    @sticky = current_user.stickies.new(params[:sticky])
    @project_id = @sticky.project_id
  end

  def edit
    @sticky = current_user.all_stickies.find_by_id(params[:id])
    @project_id = @sticky.project_id
    redirect_to root_path unless @sticky
  end

  def create
    params[:sticky][:due_date] = Date.strptime(params[:sticky][:due_date], "%m/%d/%Y") if params[:sticky] and not params[:sticky][:due_date].blank?    
    @sticky = current_user.stickies.new(params[:sticky])
    if @sticky.save
      redirect_to(@sticky, :notice => 'Sticky was successfully created.')
    else
      render :action => "new"
    end
  end

  def update
    params[:sticky][:due_date]   = Date.strptime(params[:sticky][:due_date], "%m/%d/%Y") if params[:sticky] and not params[:sticky][:due_date].blank?
    @sticky = current_user.all_stickies.find_by_id(params[:id])
    if @sticky
      if @sticky.update_attributes(params[:sticky])
        redirect_to(@sticky, :notice => 'Sticky was successfully updated.')
      else
        render :action => "edit"
      end
    else
      redirect_to root_path
    end
  end

  def destroy
    @sticky = current_user.all_stickies.find_by_id(params[:id])
    if @sticky
      @sticky.destroy
      redirect_to stickies_path
    else
      redirect_to root_path
    end
  end
end
